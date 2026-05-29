// GET /functions/v1/get-players?category=MS
// - category: MS | WS | MD | WD | XD (기본 MS)
// - 응답: { category, count, players: [{ rank, player_name, country_code, player1_id, player2_id }] }
//         rank ASC 정렬
//         player1_id / player2_id 는 bwf_players.id 참조 (단식은 player1_id만, 복식은 둘 다)
//         상세 화면(get-player) 진입용 식별자
// - 인증: 공개 (anon 키)
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const VALID_CATEGORIES = ["MS", "WS", "MD", "WD", "XD"] as const;
type Category = typeof VALID_CATEGORIES[number];

const SELECT_COLUMNS =
  "rank, player_name, country_code, player1_id, player2_id";

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
