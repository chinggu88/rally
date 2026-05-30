// GET /functions/v1/get-tournament-matches?tournament_id=123
// - tournament_id: bwf_matches.tournament_id (BWF tournament id, integer)
// - 응답: { tournament_id, count, matches: [...] } — match_time 오름차순(null 뒤),
//   동일 시각은 id 오름차순. 라운드 그룹핑/정렬은 클라이언트에서 수행한다.
// - 인증: 공개 (anon 키) — 실제 조회는 service_role로 RLS 우회
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const SELECT_COLUMNS = [
  "id",
  "tournament_id",
  "tournament_code",
  "event_name",
  "match_type",
  "round_name",
  "team1_names",
  "team1_country",
  "team1_seed",
  "team2_names",
  "team2_country",
  "team2_seed",
  "winner",
  "score",
  "match_status",
  "match_time",
  "court_name",
  "duration_min",
].join(", ");

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

    const supabase = serviceClient();
    const { data, error: dbErr } = await supabase
      .from("bwf_matches")
      .select(SELECT_COLUMNS)
      .eq("tournament_id", id)
      .order("match_time", { ascending: true, nullsFirst: false })
      .order("id", { ascending: true });

    if (dbErr) return error(dbErr.message, 500);

    return json({
      tournament_id: id,
      count: data?.length ?? 0,
      matches: data ?? [],
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
