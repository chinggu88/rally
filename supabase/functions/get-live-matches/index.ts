// GET /functions/v1/get-live-matches[?tournament_id=...][&event_name=MS|WS|MD|WD|XD]
// - 기본: tournament_status='live'인 모든 매치 (start_date 오름차순, 동률은 id 오름차순)
// - tournament_id, event_name 둘 다 선택 파라미터
// - 응답: { count, matches: [...] }
// - 인증: 공개 — 실제 조회는 service_role로 RLS 우회
// - row가 비정규화돼 있어 (name/slug/logo_url/category_name 등 매치 row에 직접 박힘)
//   클라이언트는 JOIN 없이 라이브 카드를 그릴 수 있다. raw jsonb는 응답에서 제외.
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

const EVENTS = new Set(["MS", "WS", "MD", "WD", "XD"]);

const SELECT_COLUMNS = [
  "id",
  "tournament_id",
  "tournament_code",
  "tournament_status",
  "event_name",
  "match_type",
  "round_name",
  "team1_country",
  "team1_player_ids",
  "team1_names",
  "team1_seed",
  "team2_country",
  "team2_player_ids",
  "team2_names",
  "team2_seed",
  "winner",
  "score",
  "match_status",
  "match_status_value",
  "score_status",
  "score_status_value",
  "match_time",
  "match_time_utc",
  "court_name",
  "duration_min",
  "promoted_at",
  "last_polled_at",
  "slug",
  "name",
  "start_date",
  "end_date",
  "date_label",
  "prize_money_usd",
  "detail_url",
  "logo_url",
  "header_image_url",
  "header_image_mobile_url",
  "cat_logo_url",
  "category_name",
  "tournament_category_id",
  "tournament_series_id",
  "is_etihad",
].join(", ");

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "GET") return error("method not allowed", 405);

  try {
    const url = new URL(req.url);
    const tidParam = url.searchParams.get("tournament_id");
    const evParam = url.searchParams.get("event_name");

    let tid: number | null = null;
    if (tidParam !== null) {
      const n = Number(tidParam);
      if (!Number.isInteger(n) || n <= 0) {
        return error("tournament_id must be a positive integer", 400);
      }
      tid = n;
    }
    if (evParam !== null && !EVENTS.has(evParam)) {
      return error("event_name must be one of MS, WS, MD, WD, XD", 400);
    }

    const supabase = serviceClient();
    let query = supabase
      .from("bwf_live_matches")
      .select(SELECT_COLUMNS)
      .eq("tournament_status", "live");
    if (tid !== null) query = query.eq("tournament_id", tid);
    if (evParam !== null) query = query.eq("event_name", evParam);

    const { data, error: dbErr } = await query
      .order("start_date", { ascending: true, nullsFirst: false })
      .order("id", { ascending: true });

    if (dbErr) return error(dbErr.message, 500);

    return json({
      count: data?.length ?? 0,
      matches: data ?? [],
    });
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
