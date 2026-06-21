// delete-account: 로그인 사용자가 본인 계정을 영구 삭제(회원탈퇴)하는 함수.
//
// 호출 흐름:
//   1. 호출자의 JWT를 검증해 user.id 확보 (requireUser).
//   2. service_role 클라이언트로 auth.admin.deleteUser(user.id) 실행.
//   3. auth.users 삭제 → on delete cascade 로 profiles / favorite_players /
//      device_tokens 가 함께 정리된다.
//
// 환경변수: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ANON_KEY (자동 주입).
//
// 클라이언트는 호출 성공 후 별도로 auth.signOut() 한다.
import "@supabase/functions-js/edge-runtime.d.ts";
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { requireUser, UnauthorizedError } from "../_shared/auth.ts";
import { json, error } from "../_shared/response.ts";

Deno.serve(async (req: Request) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return error("Method Not Allowed", 405);
  }

  try {
    const user = await requireUser(req);

    const admin = serviceClient();
    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) {
      console.error("delete-account: deleteUser failed", delErr.message);
      return error(`회원탈퇴에 실패했습니다: ${delErr.message}`, 500);
    }

    return json({ success: true });
  } catch (e) {
    if (e instanceof UnauthorizedError) {
      return error("로그인이 필요합니다.", 401);
    }
    console.error("delete-account: unexpected error", e);
    return error("회원탈퇴 처리 중 오류가 발생했습니다.", 500);
  }
});
