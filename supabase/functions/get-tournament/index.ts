// GET /functions/v1/get-tournament?tournament_id=123
// - tournament_id: bwf_tournaments.tournament_id (BWF tournament id, integer)
// - 응답: { tournament: {...} } — 단건. 미존재 시 404.
// - 인증: 공개 (anon 키)
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return error("method not allowed", 405);

  try {
    const url = new URL(req.url);
    const idParam = url.searchParams.get("tournament_id");
    const id = Number(idParam);
    if (!idParam || !Number.isInteger(id) || id <= 0) {
      return error("tournament_id is required and must be a positive integer", 400);
    }

    const supabase = serviceClient();
    const { data, error: dbErr } = await supabase
      .from("bwf_tournaments")
      .select("*")
      .eq("tournament_id", id)
      .maybeSingle();

    if (dbErr) return error(dbErr.message, 500);
    if (!data) return error("tournament not found", 404);

    return json({ tournament: data });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
