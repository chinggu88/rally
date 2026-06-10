// GET /functions/v1/get-today-matches[?date=YYYY-MM-DD]
//
// 홈(NewsView) "오늘 경기" 패널용. KST 기준 오늘 하루의 bwf_matches를
//   - results  (점수가 있거나 winner 확정 / Walkover·Retired)
//   - upcoming (그 외 — 경기 예정)
// 으로 분류해 반환한다. bwf_live_matches 중 tournament_status='live'인 행의 match_code만 제외
// (라이브 섹션과의 중복 방지). 라이브가 끝난(예: completed) 행은 결과 화면에 포함된다.
// 대회 비정규화(name, logo_url 등)는 bwf_tournaments JOIN 후 응답에 인라인.
//
// 인증: 공개 (anon) — 실제 조회는 service_role로 RLS 우회.

import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

const MATCH_COLUMNS = [
  "id",
  "match_code",
  "tournament_id",
  "tournament_code",
  "tournament_status",
  "event_name",
  "match_type",
  "round_name",
  "team1_country",
  "team1_player_ids",
  "team1_names",
  "team1_seed",
  "team2_country",
  "team2_player_ids",
  "team2_names",
  "team2_seed",
  "winner",
  "score",
  "match_status",
  "match_status_value",
  "score_status",
  "score_status_value",
  "match_time",
  "match_time_utc",
  "court_name",
  "location_name",
  "duration_min",
].join(", ");

const TOURNAMENT_COLUMNS = [
  "tournament_id",
  "name",
  "logo_url",
  "cat_logo_url",
  "tour_level",
  "prize_money_usd",
  "country",
  "flag_url",
  "date_label",
].join(", ");

function isValidYmd(s: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(`${s}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

function todayKstDate(now: Date = new Date()): string {
  const kstNow = new Date(now.getTime() + KST_OFFSET_MS);
  return kstNow.toISOString().slice(0, 10);
}

function kstRangeUtcIso(dateYmd: string): { gte: string; lt: string } {
  const startMs = Date.parse(`${dateYmd}T00:00:00+09:00`);
  const endMs = startMs + 24 * 60 * 60 * 1000;
  return {
    gte: new Date(startMs).toISOString(),
    lt: new Date(endMs).toISOString(),
  };
}

function toKstIsoString(ts: string | null): string | null {
  if (!ts) return null;
  const ms = Date.parse(ts);
  if (Number.isNaN(ms)) return null;
  const d = new Date(ms + KST_OFFSET_MS);
  return d.toISOString().replace(/\.\d{3}Z$/, "+09:00").replace(/Z$/, "+09:00");
}

/// KST wall-clock의 `HH:mm`을 디바이스/서버 타임존과 무관하게 추출한다.
/// `ms + 9h`로 만든 Date의 `getUTCHours/getUTCMinutes`가 곧 KST 시·분이다.
function toKstHhmm(ts: string | null): string | null {
  if (!ts) return null;
  const ms = Date.parse(ts);
  if (Number.isNaN(ms)) return null;
  const kst = new Date(ms + KST_OFFSET_MS);
  const hh = String(kst.getUTCHours()).padStart(2, "0");
  const mm = String(kst.getUTCMinutes()).padStart(2, "0");
  return `${hh}:${mm}`;
}

type ScoreSet = { set?: number; home?: number | string; away?: number | string };

function isPlayed(row: {
  score: unknown;
  winner: number | null;
  score_status_value: string | null;
}): boolean {
  if (row.winner === 1 || row.winner === 2) return true;
  const sv = (row.score_status_value ?? "").toLowerCase();
  if (sv === "walkover" || sv === "retired") return true;
  const s = row.score;
  if (!Array.isArray(s) || s.length === 0) return false;
  for (const set of s as ScoreSet[]) {
    if (!set || typeof set !== "object") continue;
    const h = Number(set.home ?? 0);
    const a = Number(set.away ?? 0);
    if ((Number.isFinite(h) && h > 0) || (Number.isFinite(a) && a > 0)) {
      return true;
    }
  }
  return false;
}

function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return error("method not allowed", 405);

  try {
    const url = new URL(req.url);
    const dateParam = url.searchParams.get("date");
    let date: string;
    if (dateParam !== null) {
      if (!isValidYmd(dateParam)) {
        return error("date must be YYYY-MM-DD", 400);
      }
      date = dateParam;
    } else {
      date = todayKstDate();
    }

    const { gte, lt } = kstRangeUtcIso(date);
    const supabase = serviceClient();

    // 1) 오늘(KST) 범위 matches
    const { data: matchRows, error: mErr } = await supabase
      .from("bwf_matches")
      .select(MATCH_COLUMNS)
      .gte("match_time", gte)
      .lt("match_time", lt)
      .order("match_time", { ascending: true, nullsFirst: false })
      .order("id", { ascending: true });
    if (mErr) return error(mErr.message, 500);
    const rowsRaw = matchRows ?? [];

    // 2) 라이브 match_code set (tournament_status='live'인 행만)
    const { data: liveRows, error: liveErr } = await supabase
      .from("bwf_live_matches")
      .select("match_code")
      .eq("tournament_status", "live");
    if (liveErr) return error(liveErr.message, 500);
    const liveCodes = new Set<string>();
    for (const r of liveRows ?? []) {
      if (r.match_code) liveCodes.add(r.match_code as string);
    }

    // 3) 라이브 제외 (현재 진행 중인 라이브와 중복되는 매치만 제거)
    const rows = rowsRaw.filter(
      (r) => !r.match_code || !liveCodes.has(r.match_code as string),
    );

    if (rows.length === 0) {
      return json({
        date,
        results_count: 0,
        upcoming_count: 0,
        results: [],
        upcoming: [],
      });
    }

    // 4) bwf_tournaments 비정규화 조회
    const tIds = new Set<number>();
    for (const r of rows) {
      if (typeof r.tournament_id === "number") tIds.add(r.tournament_id);
    }

    type TournamentRow = {
      tournament_id: number;
      name: string | null;
      logo_url: string | null;
      cat_logo_url: string | null;
      tour_level: string | null;
      prize_money_usd: number | null;
      country: string | null;
      flag_url: string | null;
      date_label: string | null;
    };
    const tournamentById = new Map<number, TournamentRow>();
    for (const part of chunk([...tIds], 200)) {
      const { data: tRows, error: tErr } = await supabase
        .from("bwf_tournaments")
        .select(TOURNAMENT_COLUMNS)
        .in("tournament_id", part);
      if (tErr) return error(tErr.message, 500);
      for (const t of (tRows ?? []) as TournamentRow[]) {
        tournamentById.set(t.tournament_id, t);
      }
    }

    // 5) 분류 + 조립
    const results: unknown[] = [];
    const upcoming: unknown[] = [];
    for (const r of rows) {
      const t = tournamentById.get(r.tournament_id as number);
      const enriched = {
        ...r,
        match_time_kst: toKstIsoString(r.match_time as string | null),
        match_time_kst_hhmm: toKstHhmm(r.match_time as string | null),
        tournament_name: t?.name ?? null,
        tournament_logo_url: t?.logo_url ?? null,
        tournament_cat_logo_url: t?.cat_logo_url ?? null,
        tournament_tour_level: t?.tour_level ?? null,
        tournament_prize_money_usd: t?.prize_money_usd ?? null,
        tournament_country: t?.country ?? null,
        tournament_flag_url: t?.flag_url ?? null,
        tournament_date_label: t?.date_label ?? null,
      };
      const played = isPlayed({
        score: r.score,
        winner: (r.winner as number | null) ?? null,
        score_status_value: (r.score_status_value as string | null) ?? null,
      });
      if (played) results.push(enriched);
      else upcoming.push(enriched);
    }
    // results / upcoming 둘 다 match_time ASC (DB order 그대로) — 클라이언트에서
    // results + upcoming 을 합쳐도 전체가 경기 시간 오름차순으로 표시된다.

    return json({
      date,
      results_count: results.length,
      upcoming_count: upcoming.length,
      results,
      upcoming,
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
