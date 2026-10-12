/**
 * send-live-activity — Live Activity(잠금화면 + 다이나믹 아일랜드) APNs 푸시.
 *
 * `live_activity_events` INSERT를 DB Webhook이 감지해 호출한다.
 * FCM을 거치지 않고 **APNs로 직접** 쏜다(Live Activity는 FCM 경유 불가).
 *
 * 필요한 secrets:
 *   APNS_KEY_P8    : Apple Developer의 .p8 인증키 전문(PEM)
 *   APNS_KEY_ID    : .p8 키의 Key ID (10자)
 *   APNS_TEAM_ID   : Apple Developer Team ID (10자)
 *   APNS_BUNDLE_ID : 앱 번들 ID (기본 com.iksun.rallys)
 *   APNS_ENV       : "sandbox" | "production" (기본 sandbox)
 *
 *   설정: supabase secrets set APNS_KEY_P8="$(cat AuthKey_XXXX.p8)" ...
 */
import { handlePreflight } from "../_shared/cors.ts";
import { error, json } from "../_shared/response.ts";
import { serviceClient } from "../_shared/supabase.ts";

// ── APNs JWT (ES256) ────────────────────────────────────────

/**
 * APNs provider token 캐시.
 *
 * APNs는 토큰을 20~60분간 재사용하도록 요구한다. 매번 새로 만들면
 * `TooManyProviderTokenUpdates(429)`로 차단된다.
 */
let cachedJwt: { token: string; issuedAt: number } | null = null;
const JWT_TTL_SECONDS = 45 * 60;

function b64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function b64urlJson(obj: unknown): string {
  return b64url(new TextEncoder().encode(JSON.stringify(obj)));
}

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && now - cachedJwt.issuedAt < JWT_TTL_SECONDS) {
    return cachedJwt.token;
  }

  const p8 = Deno.env.get("APNS_KEY_P8");
  const keyId = Deno.env.get("APNS_KEY_ID");
  const teamId = Deno.env.get("APNS_TEAM_ID");
  if (!p8 || !keyId || !teamId) {
    throw new Error("APNS_KEY_P8 / APNS_KEY_ID / APNS_TEAM_ID must be set");
  }

  const pem = p8
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\s/g, "")
    .trim();
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );

  const signingInput = `${b64urlJson({ alg: "ES256", kid: keyId })}.${
    b64urlJson({ iss: teamId, iat: now })
  }`;

  // WebCrypto ECDSA는 raw r||s를 반환한다 — APNs가 원하는 형식 그대로다
  // (DER 인코딩이 아니므로 추가 변환이 필요 없다).
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );

  const token = `${signingInput}.${b64url(new Uint8Array(sig))}`;
  cachedJwt = { token, issuedAt: now };
  return token;
}

// ── 전송 ────────────────────────────────────────────────────

type PrevSet = { text: string; won: boolean };

/**
 * `bwf_live_matches.score`를 게임별 점수쌍으로 파싱한다.
 *
 * 실제 저장 형태는 jsonb 배열이다:
 *   [{"set":1,"home":21,"away":14}, {"set":2,"home":21,"away":12}]
 * home = team1, away = team2 로 매핑한다(배치 파서 기준).
 *
 * 과거 형식("21-18, 21-15" 문자열)도 방어적으로 함께 받는다.
 */
function parseGames(score: unknown): number[][] {
  if (score == null) return [];

  if (Array.isArray(score)) {
    const games: number[][] = [];
    for (const raw of score) {
      if (raw && typeof raw === "object") {
        const o = raw as Record<string, unknown>;
        const h = Number(o.home ?? o.team1 ?? o.t1);
        const a = Number(o.away ?? o.team2 ?? o.t2);
        if (Number.isFinite(h) && Number.isFinite(a)) games.push([h, a]);
      } else if (Array.isArray(raw) && raw.length >= 2) {
        const h = Number(raw[0]);
        const a = Number(raw[1]);
        if (Number.isFinite(h) && Number.isFinite(a)) games.push([h, a]);
      }
    }
    // set 번호가 있으면 그 순서를 신뢰한다.
    return games;
  }

  if (typeof score === "string") {
    const games: number[][] = [];
    for (const token of score.split(/\s*,\s*|\s+/)) {
      const m = token.match(/(\d+)\s*[-:/]\s*(\d+)/);
      if (!m) continue;
      const a = parseInt(m[1], 10);
      const b = parseInt(m[2], 10);
      if (!Number.isNaN(a) && !Number.isNaN(b)) games.push([a, b]);
    }
    return games;
  }

  return [];
}

/**
 * ContentState 빌드 — **Swift의 `RallyMatchAttributes.ContentState`와
 * 키가 1:1로 일치해야 한다.**
 */
function buildContentState(
  score: unknown,
  meta: string,
  isFinal: boolean,
) {
  const games = parseGames(score);
  const current = games.length === 0 ? [0, 0] : games[games.length - 1];
  const prevSets: PrevSet[] = games.slice(0, -1).map((g) => ({
    text: `${g[0]}–${g[1]}`,
    won: g[0] > g[1],
  }));

  return {
    current,
    setLabel: games.length === 0 ? "" : `${games.length}세트`,
    prevSets,
    meta,
    isFinished: isFinal,
  };
}

async function sendApns(
  pushToken: string,
  contentState: unknown,
  isFinal: boolean,
  jwt: string,
): Promise<{ ok: boolean; status: number; body: string }> {
  const host = Deno.env.get("APNS_ENV") === "production"
    ? "api.push.apple.com"
    : "api.sandbox.push.apple.com";
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") ?? "com.iksun.rallys";

  const payload = {
    aps: {
      timestamp: Math.floor(Date.now() / 1000),
      event: isFinal ? "end" : "update",
      "content-state": contentState,
      // 경기 종료 시 잠금화면에서 즉시 내린다.
      ...(isFinal ? { "dismissal-date": Math.floor(Date.now() / 1000) } : {}),
    },
  };

  const res = await fetch(`https://${host}/3/device/${pushToken}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${jwt}`,
      "apns-topic": `${bundleId}.push-type.liveactivity`,
      "apns-push-type": "liveactivity",
      "apns-priority": isFinal ? "10" : "5",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  return { ok: res.ok, status: res.status, body: res.ok ? "" : await res.text() };
}

// ── 핸들러 ──────────────────────────────────────────────────

Deno.serve(async (req) => {
  const pre = handlePreflight(req);
  if (pre) return pre;
  if (req.method !== "POST") return error("Method not allowed", 405);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return error("Invalid JSON body", 400);
  }

  if (body.type !== "INSERT" || body.table !== "live_activity_events") {
    return json({ skipped: "not a live_activity_events insert" });
  }

  const event = body.record as {
    id: string;
    match_code: string;
    score: unknown;
    match_status: string | null;
    is_final: boolean;
    status: string;
  };
  if (!event || event.status !== "pending") {
    return json({ skipped: "not pending" });
  }

  const supabase = serviceClient();

  const { data: tokens, error: tokenErr } = await supabase
    .from("live_activity_tokens")
    .select("push_token, user_id")
    .eq("match_code", event.match_code);

  if (tokenErr) {
    await markEvent(supabase, event.id, "failed", tokenErr.message);
    return error(tokenErr.message, 500);
  }
  if (!tokens || tokens.length === 0) {
    await markEvent(supabase, event.id, "sent", null);
    return json({ sent: 0, reason: "no tokens" });
  }

  // 코트/라운드/종목 메타는 관심 경기 스냅샷에서 가져온다.
  const { data: fav } = await supabase
    .from("favorite_matches")
    .select("court_name, round_name, event_name")
    .eq("match_code", event.match_code)
    .limit(1)
    .maybeSingle();

  const meta = [fav?.court_name, fav?.round_name, fav?.event_name]
    .filter((v) => typeof v === "string" && v.trim().length > 0)
    .join(" · ");

  const contentState = buildContentState(event.score, meta, event.is_final);

  let jwt: string;
  try {
    jwt = await getApnsJwt();
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await markEvent(supabase, event.id, "failed", msg);
    return error(msg, 500);
  }

  const results = await Promise.all(
    tokens.map((t) =>
      sendApns(t.push_token as string, contentState, event.is_final, jwt)
        .then((r) => ({ ...r, token: t.push_token as string }))
        .catch((e) => ({
          ok: false,
          status: 0,
          body: e instanceof Error ? e.message : String(e),
          token: t.push_token as string,
        }))
    ),
  );

  // 죽은 토큰 정리 — 410 Gone은 활동이 이미 끝났다는 뜻이다.
  const dead = results.filter((r) => r.status === 410).map((r) => r.token);
  if (dead.length > 0) {
    await supabase.from("live_activity_tokens").delete().in("push_token", dead);
  }
  // 경기가 끝났으면 토큰을 모두 정리한다.
  if (event.is_final) {
    await supabase.from("live_activity_tokens")
      .delete().eq("match_code", event.match_code);
  }

  const failed = results.filter((r) => !r.ok && r.status !== 410);
  await markEvent(
    supabase,
    event.id,
    failed.length === results.length && results.length > 0 ? "failed" : "sent",
    failed.length > 0 ? `${failed.length} failed: ${failed[0].body}` : null,
  );

  return json({
    sent: results.filter((r) => r.ok).length,
    failed: failed.length,
    dead: dead.length,
  });
});

async function markEvent(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  id: string,
  status: "sent" | "failed",
  errorMessage: string | null,
) {
  await supabase.from("live_activity_events").update({
    status,
    error_message: errorMessage,
    sent_at: new Date().toISOString(),
  }).eq("id", id);
}
