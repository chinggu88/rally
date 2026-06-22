// GET /functions/v1/get-news-cards?page=1&per_page=20
// - card_created = true 인 badminton_planet_news 행만 조회한다 (카드뉴스가 만들어진 기사).
// - page:     1부터 시작하는 페이지 번호 (기본 1, 1 미만이면 1로 보정)
// - per_page: 페이지당 개수 (기본 20, 1~100 범위로 보정)
// - 응답: { page, per_page, count, total, cards: [{ id, card_storage_paths }] }
//         count = 이번 페이지 행 수, total = card_created=true 전체 건수
//         card_storage_paths = 생성된 카드뉴스 이미지의 Storage 경로 배열
//         정렬: published_at DESC NULLS LAST → id DESC (최신 기사 우선)
// - 인증: 공개 (anon 키)
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const DEFAULT_PER_PAGE = 20;
const MAX_PER_PAGE = 100;

// 쿼리 파라미터를 정수로 파싱하되 범위를 벗어나면 fallback 으로 보정한다.
function parseIntParam(
  raw: string | null,
  fallback: number,
  min: number,
  max: number,
): number {
  // 미전달/빈 문자열은 fallback. (Number(null)/Number("")는 0이 되어버리므로 먼저 거른다.)
  if (raw === null || raw.trim() === "") return fallback;
  const n = Number(raw);
  if (!Number.isInteger(n)) return fallback;
  if (n < min) return min;
  if (n > max) return max;
  return n;
}

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return error("method not allowed", 405);

  try {
    const url = new URL(req.url);
    const page = parseIntParam(
      url.searchParams.get("page"),
      1,
      1,
      Number.MAX_SAFE_INTEGER,
    );
    const perPage = parseIntParam(
      url.searchParams.get("per_page"),
      DEFAULT_PER_PAGE,
      1,
      MAX_PER_PAGE,
    );

    const from = (page - 1) * perPage;
    const to = from + perPage - 1;

    const supabase = serviceClient();
    const { data, count, error: dbErr } = await supabase
      .from("badminton_planet_news")
      .select("id, card_storage_paths", { count: "exact" })
      .eq("card_created", true)
      .not("card_storage_paths", "is", null)
      .order("published_at", { ascending: false, nullsFirst: false })
      .order("id", { ascending: false })
      .range(from, to);

    if (dbErr) {
      // 데이터 범위를 벗어난 페이지(예: 마지막 페이지 이후) 요청은 에러가 아니라
      // 빈 페이지로 응답한다. PostgREST: code=PGRST103 "Requested range not satisfiable".
      if (
        dbErr.code === "PGRST103" ||
        dbErr.message.toLowerCase().includes("range not satisfiable")
      ) {
        return json({
          page,
          per_page: perPage,
          count: 0,
          total: count ?? 0,
          cards: [],
        });
      }
      return error(dbErr.message, 500);
    }

    const cards = (data ?? []).map((r) => ({
      id: r.id,
      card_storage_paths: r.card_storage_paths,
    }));

    return json({
      page,
      per_page: perPage,
      count: cards.length,
      total: count ?? cards.length,
      cards,
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
