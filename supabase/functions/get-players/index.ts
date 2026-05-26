// GET /functions/v1/get-players?category=MS
// - category: MS | WS | MD | WD | XD (기본 MS)
// - 응답: { category, count, players: [{ rank, player_name, country_code }] }
//         rank ASC 정렬
// - 인증: 공개 (anon 키)
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const VALID_CATEGORIES = ["MS", "WS", "MD", "WD", "XD"] as const;
type Category = typeof VALID_CATEGORIES[number];

const SELECT_COLUMNS = "rank, player_name, country_code";

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return error("method not allowed", 405);

  try {
    const url = new URL(req.url);
    const categoryParam = (url.searchParams.get("category") ?? "MS").toUpperCase();
    if (!VALID_CATEGORIES.includes(categoryParam as Category)) {
      return error(
        `category must be one of: ${VALID_CATEGORIES.join(", ")}`,
        400,
      );
    }
    const category = categoryParam as Category;

    const supabase = serviceClient();
    const { data, error: dbErr } = await supabase
      .from("bwf_rankings")
      .select(SELECT_COLUMNS)
      .eq("category", category)
      .order("rank", { ascending: true });

    if (dbErr) return error(dbErr.message, 500);

    return json({
      category,
      count: data?.length ?? 0,
      players: data ?? [],
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
