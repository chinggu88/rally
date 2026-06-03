// GET /functions/v1/get-live-matches[?tournament_id=...][&event_name=MS|WS|MD|WD|XD]
// - 기본: tournament_status='live'인 모든 매치 (start_date 오름차순, 동률은 id 오름차순)
// - tournament_id, event_name 둘 다 선택 파라미터
// - 응답: { count, matches: [...] }
//   각 match row에 team1_player_avatars / team2_player_avatars 필드를 추가한다.
//   각 배열의 i번째 원소는 team{n}_player_ids[i] 가 가리키는 bwf_players.photo_url.
//   매칭되는 row가 없거나 photo_url 이 NULL 이면 해당 위치는 null.
// - 인증: 공개 — 실제 조회는 service_role로 RLS 우회
// - row가 비정규화돼 있어 (name/slug/logo_url/category_name 등 매치 row에 직접 박힘)
//   클라이언트는 JOIN 없이 라이브 카드를 그릴 수 있다. raw jsonb는 응답에서 제외.
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const EVENTS = new Set(["MS", "WS", "MD", "WD", "XD"]);

const SELECT_COLUMNS = [
  "id",
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
  "duration_min",
  "promoted_at",
  "last_polled_at",
  "slug",
  "name",
  "start_date",
  "end_date",
  "date_label",
  "prize_money_usd",
  "detail_url",
  "logo_url",
  "header_image_url",
  "header_image_mobile_url",
  "cat_logo_url",
  "category_name",
  "tournament_category_id",
  "tournament_series_id",
  "is_etihad",
].join(", ");

// 큰 id 목록은 URL 길이 제한을 피하려 청크 단위로 in() 조회한다.
function chunk<T>(arr: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < arr.length; i += size) out.push(arr.slice(i, i + size));
  return out;
}

// 다양한 표기(int / string / null)로 들어올 수 있는 player id 배열을
// number[] 로 정규화한다. 정수로 파싱 안 되는 값은 버린다.
function normalizePlayerIds(value: unknown): number[] {
  if (!Array.isArray(value)) return [];
  const out: number[] = [];
  for (const v of value) {
    if (typeof v === "number" && Number.isFinite(v)) {
      out.push(v);
    } else if (typeof v === "string") {
      const n = Number(v);
      if (Number.isInteger(n)) out.push(n);
    }
  }
  return out;
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return error("method not allowed", 405);

  try {
    const url = new URL(req.url);
    const tidParam = url.searchParams.get("tournament_id");
    const evParam = url.searchParams.get("event_name");

    let tid: number | null = null;
    if (tidParam !== null) {
      const n = Number(tidParam);
      if (!Number.isInteger(n) || n <= 0) {
        return error("tournament_id must be a positive integer", 400);
      }
      tid = n;
    }
    if (evParam !== null && !EVENTS.has(evParam)) {
      return error("event_name must be one of MS, WS, MD, WD, XD", 400);
    }

    const supabase = serviceClient();
    let query = supabase
      .from("bwf_live_matches")
      .select(SELECT_COLUMNS)
      .eq("tournament_status", "live");
    if (tid !== null) query = query.eq("tournament_id", tid);
    if (evParam !== null) query = query.eq("event_name", evParam);

    const { data, error: dbErr } = await query
      .order("start_date", { ascending: true, nullsFirst: false })
      .order("id", { ascending: true });

    if (dbErr) return error(dbErr.message, 500);

    const rows = data ?? [];

    // 모든 매치의 team1/team2 player id 합집합으로 bwf_players.photo_url 일괄 조회
    const allIds = new Set<number>();
    for (const r of rows) {
      for (const id of normalizePlayerIds(r.team1_player_ids)) allIds.add(id);
      for (const id of normalizePlayerIds(r.team2_player_ids)) allIds.add(id);
    }

    const photoById = new Map<number, string | null>();
    for (const part of chunk([...allIds], 200)) {
      const { data: players, error: pErr } = await supabase
        .from("bwf_players")
        .select("id, photo_url")
        .in("id", part);
      if (pErr) return error(pErr.message, 500);
      for (const p of players ?? []) {
        photoById.set(p.id as number, (p.photo_url as string | null) ?? null);
      }
    }

    const matches = rows.map((r) => {
      const t1Ids = normalizePlayerIds(r.team1_player_ids);
      const t2Ids = normalizePlayerIds(r.team2_player_ids);
      return {
        ...r,
        team1_player_avatars: t1Ids.map((id) => photoById.get(id) ?? null),
        team2_player_avatars: t2Ids.map((id) => photoById.get(id) ?? null),
      };
    });

    return json({
      count: matches.length,
      matches,
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
