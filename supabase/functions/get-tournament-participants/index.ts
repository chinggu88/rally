// GET /functions/v1/get-tournament-participants?tournament_id=123&event_name=MS
// - tournament_id: bwf_tournaments.tournament_id (BWF tournament id, integer)
// - event_name: MS | WS | MD | WD | XD (필수, 종목별 탭 UI 가정)
// - 응답: { tournament_id, event_name, count, participants: [...] }
//   participants[i] = {
//     event_name, player1_id, player2_id,
//     player1_name, player2_name,
//     country, seed, first_round,
//     photo_url   // player1_id 가 가리키는 bwf_players.photo_url (대표 1인)
//   }
//   정렬: seed ASC nulls last → player1_name ASC
//   단식은 player2_* / 복식은 둘 다 채워짐.
// - 데이터 소스: bwf_tournament_participants_view (bwf_matches에서 derive)
// - 한계: 대진 발표 전 entry list/기권자는 표시 불가 (view 코멘트 참조)
// - 인증: 공개 (anon 키) — 실제 조회는 service_role로 RLS 우회
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const VALID_EVENTS = ["MS", "WS", "MD", "WD", "XD"] as const;
type Event = typeof VALID_EVENTS[number];

const SELECT_COLUMNS = [
  "event_name",
  "player1_id",
  "player2_id",
  "player1_name",
  "player2_name",
  "country",
  "seed",
  "first_round",
].join(", ");

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
    const url = new URL(req.url);

    const idParam = url.searchParams.get("tournament_id");
    const id = Number(idParam);
    if (!idParam || !Number.isInteger(id) || id <= 0) {
      return error(
        "tournament_id is required and must be a positive integer",
        400,
      );
    }

    const eventParam = url.searchParams.get("event_name");
    if (!eventParam) {
      return error("event_name is required", 400);
    }
    const eventName = eventParam.toUpperCase();
    if (!VALID_EVENTS.includes(eventName as Event)) {
      return error(
        `event_name must be one of: ${VALID_EVENTS.join(", ")}`,
        400,
      );
    }

    const supabase = serviceClient();
    const { data, error: dbErr } = await supabase
      .from("bwf_tournament_participants_view")
      .select(SELECT_COLUMNS)
      .eq("tournament_id", id)
      .eq("event_name", eventName)
      .order("seed", { ascending: true, nullsFirst: false })
      .order("player1_name", { ascending: true });

    if (dbErr) return error(dbErr.message, 500);

    const rows = data ?? [];

    // 대표(player1) id 목록으로 bwf_players.photo_url 일괄 조회
    const ids = [
      ...new Set(
        rows
          .map((r) => r.player1_id as number | null)
          .filter((v): v is number => v != null),
      ),
    ];
    const photoById = new Map<number, string | null>();
    for (const part of chunk(ids, 200)) {
      const { data: players, error: pErr } = await supabase
        .from("bwf_players")
        .select("id, photo_url")
        .in("id", part);
      if (pErr) return error(pErr.message, 500);
      for (const p of players ?? []) {
        photoById.set(p.id as number, (p.photo_url as string | null) ?? null);
      }
    }

    const participants = rows.map((r) => ({
      event_name: r.event_name,
      player1_id: r.player1_id,
      player2_id: r.player2_id,
      player1_name: r.player1_name,
      player2_name: r.player2_name,
      country: r.country,
      seed: r.seed,
      first_round: r.first_round,
      photo_url: r.player1_id != null
        ? (photoById.get(r.player1_id as number) ?? null)
        : null,
    }));

    return json({
      tournament_id: id,
      event_name: eventName,
      count: participants.length,
      participants,
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
