// GET /functions/v1/get-active-tournaments-kr
//
// 오늘 날짜를 포함해 "진행중(ongoing) + 진행예정(upcoming)"인 대회를 조회하고,
// 각 대회의 참가 선수 중 한국 선수(KOR)가 몇 명인지 집계해 반환한다.
//
// - 대상 대회: end_date >= today (진행중) 또는 start_date >= today (진행예정)
//   start_date 오름차순 정렬.
// - 응답(필수 필드): country(개최국가), name(대회명), points(점수),
//   start_date/end_date/date_label(날짜), korean_player_count(한국 선수 참여 인원).
// - 부가 필드: status, tour_level, location, prize_money_usd, has_live_scores,
//   participant_count, korean_players[](id/name), flag_url/logo_url 등.
//
// 점수(points): BWF World Tour 우승자 기준 랭킹 포인트를 tour_level로 매핑.
//   매핑되지 않는 카테고리(Team/Individual 등)는 null.
//
// 한국 선수 식별: 참가 선수 id를 bwf_players.country_code = 'KOR' 로 조회.
//   - country_code 는 ISO3 (KOR) 라 매칭이 안정적이다.
//   - 참가자 데이터는 bwf_tournament_participants_view (bwf_matches에서 derive)라
//     대진 발표 전(예정 대회)에는 0명으로 집계될 수 있다. (view 코멘트 참조)
//
// 인증: 공개 (anon 키) — 실제 조회는 service_role로 RLS 우회.
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const KOR = "KOR";

const TOURNAMENT_COLUMNS = [
  "tournament_id",
  "name",
  "tour_level",
  "start_date",
  "end_date",
  "date_label",
  "country",
  "location",
  "prize_money_usd",
  "flag_url",
  "logo_url",
  "cat_logo_url",
  "status",
  "has_live_scores",
].join(", ");

// BWF World Tour 우승자 기준 랭킹 포인트(점수). tour_level 텍스트를 정규화해 매핑.
const POINTS_BY_LEVEL: Record<string, number> = {
  FINALS: 2000,
  SUPER1000: 1000,
  SUPER750: 750,
  SUPER500: 500,
  SUPER300: 300,
  SUPER100: 100,
};

function normalizeLevel(level: string | null): string {
  return (level ?? "").toUpperCase().replace(/[\s_-]/g, "");
}

function pointsForLevel(level: string | null): number | null {
  const key = normalizeLevel(level);
  if (key in POINTS_BY_LEVEL) return POINTS_BY_LEVEL[key];
  // "WORLDTOURFINALS" 같은 변형도 FINALS로 흡수
  if (key.includes("FINALS")) return POINTS_BY_LEVEL.FINALS;
  return null;
}

function deriveStatus(
  start: string | null,
  end: string | null,
  today: string,
): "ongoing" | "upcoming" | "unknown" {
  if (start && start > today) return "upcoming";
  if (start && start <= today && (!end || end >= today)) return "ongoing";
  if (!start && end && end >= today) return "ongoing";
  return "unknown";
}

// 큰 id 목록은 URL 길이 제한을 피하려 청크 단위로 in() 조회한다.
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
    // YYYY-MM-DD (UTC 기준). date 컬럼과 문자열 비교.
    const today = new Date().toISOString().slice(0, 10);

    const supabase = serviceClient();

    // 1) 오늘 포함 진행중 + 진행예정 대회
    const { data: tournamentsRaw, error: tErr } = await supabase
      .from("bwf_tournaments")
      .select(TOURNAMENT_COLUMNS)
      .or(`end_date.gte.${today},start_date.gte.${today}`)
      .order("start_date", { ascending: true });

    if (tErr) return error(tErr.message, 500);

    const tournaments = tournamentsRaw ?? [];
    if (tournaments.length === 0) {
      return json({ today, count: 0, tournaments: [] });
    }

    const tournamentIds = tournaments.map((t) => t.tournament_id as number);

    // 2) 해당 대회들의 참가 선수 일괄 조회 (tournament_id별 그룹핑)
    type Part = {
      tournament_id: number;
      player1_id: number | null;
      player2_id: number | null;
      player1_name: string | null;
      player2_name: string | null;
    };
    const partsByTournament = new Map<number, Part[]>();
    const allPlayerIds = new Set<number>();

    for (const part of chunk(tournamentIds, 200)) {
      const { data: rows, error: pErr } = await supabase
        .from("bwf_tournament_participants_view")
        .select(
          "tournament_id, player1_id, player2_id, player1_name, player2_name",
        )
        .in("tournament_id", part);
      if (pErr) return error(pErr.message, 500);

      for (const r of (rows ?? []) as Part[]) {
        const list = partsByTournament.get(r.tournament_id) ?? [];
        list.push(r);
        partsByTournament.set(r.tournament_id, list);
        if (r.player1_id != null) allPlayerIds.add(r.player1_id);
        if (r.player2_id != null) allPlayerIds.add(r.player2_id);
      }
    }

    // 3) 한국 선수 id 집합 (country_code = KOR)
    const koreanIds = new Set<number>();
    const idList = [...allPlayerIds];
    for (const part of chunk(idList, 200)) {
      const { data: players, error: plErr } = await supabase
        .from("bwf_players")
        .select("id")
        .eq("country_code", KOR)
        .in("id", part);
      if (plErr) return error(plErr.message, 500);
      for (const p of players ?? []) koreanIds.add(p.id as number);
    }

    // 4) 대회별 집계 후 응답 조립
    const result = tournaments.map((t) => {
      const tid = t.tournament_id as number;
      const parts = partsByTournament.get(tid) ?? [];

      // 대회 내 고유 선수 id (단식=player1, 복식=player1+player2)
      const uniquePlayers = new Map<number, string | null>();
      for (const p of parts) {
        if (p.player1_id != null && !uniquePlayers.has(p.player1_id)) {
          uniquePlayers.set(p.player1_id, p.player1_name);
        }
        if (p.player2_id != null && !uniquePlayers.has(p.player2_id)) {
          uniquePlayers.set(p.player2_id, p.player2_name);
        }
      }

      const koreanPlayers = [...uniquePlayers.entries()]
        .filter(([id]) => koreanIds.has(id))
        .map(([id, name]) => ({ player_id: id, name }));

      return {
        tournament_id: tid,
        // 필수 필드
        country: t.country, // 개최 국가
        name: t.name, // 대회명
        points: pointsForLevel(t.tour_level as string | null), // 점수
        start_date: t.start_date, // 날짜
        end_date: t.end_date,
        date_label: t.date_label,
        korean_player_count: koreanPlayers.length, // 한국 선수 참여 인원
        // 부가 필드
        status: deriveStatus(
          t.start_date as string | null,
          t.end_date as string | null,
          today,
        ),
        tour_level: t.tour_level,
        location: t.location,
        prize_money_usd: t.prize_money_usd,
        has_live_scores: t.has_live_scores,
        participant_count: uniquePlayers.size,
        korean_players: koreanPlayers,
        flag_url: t.flag_url,
        logo_url: t.logo_url,
        cat_logo_url: t.cat_logo_url,
      };
    });

    return json({
      today,
      count: result.length,
      tournaments: result,
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
