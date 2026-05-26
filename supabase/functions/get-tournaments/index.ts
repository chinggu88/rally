// GET /functions/v1/get-tournaments?year=YYYY
// - year 미지정 시 현재 연도
// - 응답: { year, count, tournaments: [...] } — start_date 오름차순 정렬
// - 인증: 공개 (anon 키)
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const SELECT_COLUMNS = [
  "tournament_id",
  "name",
  "tour_level",
  "start_date",
  "end_date",
  "date_label",
  "country",
  "location",
  "prize_money_usd",
  "detail_url",
  "flag_url",
  "logo_url",
  "cat_logo_url",
  "status",
  "has_live_scores",
].join(", ");

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return error("method not allowed", 405);

  try {
    const url = new URL(req.url);
    const yearParam = url.searchParams.get("year");
    const year = yearParam ? Number(yearParam) : new Date().getFullYear();
    if (!Number.isInteger(year) || year < 2000 || year > 2100) {
      return error("year must be a valid year (2000-2100)", 400);
    }

    const supabase = serviceClient();
    const { data, error: dbErr } = await supabase
      .from("bwf_tournaments")
      .select(SELECT_COLUMNS)
      .eq("year", year)
      .order("start_date", { ascending: true });

    if (dbErr) return error(dbErr.message, 500);

    return json({
      year,
      count: data?.length ?? 0,
      tournaments: data ?? [],
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
