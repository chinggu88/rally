// 응답 헬퍼 — JSON + CORS 헤더를 자동 부착.
import { corsHeaders } from "./cors.ts";

export function json(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      ...(init.headers ?? {}),
    },
  });
}

export function error(message: string, status = 500): Response {
  return json({ error: message }, { status });
}
