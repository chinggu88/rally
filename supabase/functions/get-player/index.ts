// GET /functions/v1/get-player?id=123
// - id: bwf_players PK (bigint)
// - 응답: { player: {...} } — 단건. 미존재 시 404.
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
    const idParam = url.searchParams.get("id");
    const id = Number(idParam);
    if (!idParam || !Number.isInteger(id) || id <= 0) {
      return error("id is required and must be a positive integer", 400);
    }

    const supabase = serviceClient();
    const { data, error: dbErr } = await supabase
      .from("bwf_players")
      .select("*")
      .eq("id", id)
      .maybeSingle();

    if (dbErr) return error(dbErr.message, 500);
    if (!data) return error("player not found", 404);

    return json({ player: data });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
