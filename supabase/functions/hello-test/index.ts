// 테스트용 Edge Function 샘플.
// _shared/ 헬퍼 사용 패턴 + GET/POST 분기 + DB 조회 예시를 모두 포함.

import "@supabase/functions-js/edge-runtime.d.ts";
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  try {
    if (req.method === "GET") {
      return json({
        message: "hello from edge function",
        method: req.method,
        now: new Date().toISOString(),
      });
    }

    if (req.method === "POST") {
      const body = await req.json().catch(() => ({}));
      const name = body.name ?? "world";

      const supabase = serviceClient();
      const { data, error: dbErr } = await supabase
        .from("bwf_tournaments")
        .select("id, name")
        .limit(3);

      if (dbErr) return error(dbErr.message, 500);

      return json({
        greeting: `Hello, ${name}!`,
        sample_tournaments: data,
      });
    }

    return error("method not allowed", 405);
  } catch (e) {
    return error(e instanceof Error ? e.message : "unknown", 500);
  }
});
