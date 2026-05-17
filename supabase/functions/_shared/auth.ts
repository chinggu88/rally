// JWT 검증 헬퍼.
// 호출자 식별이 필요한 엔드포인트에서 사용: const user = await requireUser(req);
import { userClient } from "./supabase.ts";

export class UnauthorizedError extends Error {
  constructor(message = "Unauthorized") {
    super(message);
    this.name = "UnauthorizedError";
  }
}

export async function requireUser(req: Request) {
  const client = userClient(req);
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new UnauthorizedError(error?.message);
  return data.user;
}
