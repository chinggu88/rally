// GET /functions/v1/get-players?category=MS
// - category: MS | WS | MD | WD | XD (기본 MS)
// - 응답: { category, count, players: [{ rank, player_name, country_code, country_name, points, rank_change, player1_id, player2_id, photo_url, photo_url2 }] }
//         rank ASC 정렬
//         points = 랭킹 포인트(numeric), rank_change = 직전 발표 대비 순위 변동(+상승/-하락/0/null)
//         player1_id / player2_id 는 member_id("123" 또는 "123-456")에서 파싱한 bwf_players.id
//         (단식은 player1_id만, 복식은 둘 다) — 상세 화면(get-player) 진입용 식별자
//         photo_url   = player1_id 가 가리키는 bwf_players.photo_url
//         photo_url2  = player2_id 가 가리키는 bwf_players.photo_url (복식 전용, 단식은 null)
// - 인증: 공개 (anon 키)
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const VALID_CATEGORIES = ["MS", "WS", "MD", "WD", "XD"] as const;
type Category = typeof VALID_CATEGORIES[number];

// bwf_rankings.player1_id 백필이 비어 있어도 동작하도록 member_id 에서 직접 파싱한다.
const SELECT_COLUMNS =
  "rank, player_name, country_code, country_name, member_id, points, rank_change";

// "123" → [123, null], "123-456" → [123, 456], 그 외 → [null, null]
function parseMemberId(memberId: unknown): [number | null, number | null] {
  if (typeof memberId !== "string") return [null, null];
  const m = memberId.match(/^(\d+)(?:-(\d+))?$/);
  if (!m) return [null, null];
  return [Number(m[1]), m[2] ? Number(m[2]) : null];
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

    // member_id → player1_id / player2_id 파싱
    const rows = (data ?? []).map((r) => {
      const [p1, p2] = parseMemberId(r.member_id);
      return {
        rank: r.rank,
        player_name: r.player_name,
        country_code: r.country_code,
        country_name: r.country_name,
        points: r.points,
        rank_change: r.rank_change,
        player1_id: p1,
        player2_id: p2,
      };
    });

    // player1 + player2 id 합집합으로 bwf_players.photo_url 일괄 조회
    const ids = [
      ...new Set(
        rows
          .flatMap((r) => [r.player1_id, r.player2_id])
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

    const players = rows.map((r) => ({
      ...r,
      photo_url: r.player1_id != null
        ? (photoById.get(r.player1_id) ?? null)
        : null,
      photo_url2: r.player2_id != null
        ? (photoById.get(r.player2_id) ?? null)
        : null,
    }));

    return json({
      category,
      count: players.length,
      players,
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
