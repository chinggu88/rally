// send-push: notifications 테이블의 INSERT 트리거로 호출되는 푸시 발송 함수.
//
// 호출 흐름:
//   1. DB Webhook이 notifications INSERT 시 이 함수로 payload 전송
//   2. payload.record.id로 notifications 행 + 대상 user_id의 device_tokens 조회
//   3. Firebase Service Account JSON으로 OAuth2 access_token 발급
//   4. 각 디바이스 토큰에 대해 FCM v1 send API 호출
//   5. 결과에 따라 notifications.status = 'sent' | 'failed' 업데이트
//   6. UNREGISTERED/NOT_FOUND 토큰은 device_tokens에서 자동 삭제 (stale token 정리)
//
// 환경변수:
//   - FIREBASE_SERVICE_ACCOUNT_JSON: Firebase Admin SDK 서비스 계정 JSON (전체 내용)
//   - PUSH_WEBHOOK_SECRET: DB Webhook 호출 시 Authorization 헤더로 검증할 공유 비밀
//   - SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY: 자동 주입됨

import "@supabase/functions-js/edge-runtime.d.ts";
import { handlePreflight } from "../_shared/cors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import { json, error } from "../_shared/response.ts";

// ─────────────────────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────────────────────

interface DbWebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: NotificationRow;
  old_record: NotificationRow | null;
}

interface NotificationRow {
  id: string;
  user_id: string;
  title: string;
  body: string;
  data: Record<string, unknown> | null;
  status: "pending" | "sent" | "failed";
}

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

interface FcmSendResult {
  token: string;
  success: boolean;
  errorCode?: string;
  errorMessage?: string;
}

// ─────────────────────────────────────────────────────────────
// Firebase OAuth2: Service Account JSON → Google access_token
// FCM v1 API는 OAuth2 Bearer 토큰을 요구한다. JWT를 자체 서명해
// https://oauth2.googleapis.com/token 에 교환 요청해서 받음.
// ─────────────────────────────────────────────────────────────

async function getGoogleAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const header = { alg: "RS256", typ: "JWT" };

  const enc = (obj: unknown) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const signingInput = `${enc(header)}.${enc(claim)}`;

  // PEM → CryptoKey
  const pem = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\\n/g, "")
    .replace(/\n/g, "")
    .trim();

  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    der,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const sig = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput),
  );

  const sigB64 = btoa(String.fromCharCode(...new Uint8Array(sig)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${signingInput}.${sigB64}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const text = await tokenRes.text();
    throw new Error(`Google OAuth2 token exchange failed: ${text}`);
  }

  const tokenJson = await tokenRes.json();
  return tokenJson.access_token as string;
}

// ─────────────────────────────────────────────────────────────
// FCM v1 send: 단일 디바이스 토큰에 푸시 발송
// ─────────────────────────────────────────────────────────────

async function sendFcm(
  projectId: string,
  accessToken: string,
  deviceToken: string,
  notification: NotificationRow,
): Promise<FcmSendResult> {
  const url =
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  // FCM v1 message — data 필드는 string-only.
  const dataStr: Record<string, string> = {};
  if (notification.data && typeof notification.data === "object") {
    for (const [k, v] of Object.entries(notification.data)) {
      dataStr[k] = typeof v === "string" ? v : JSON.stringify(v);
    }
  }
  dataStr["notification_id"] = notification.id;

  const message = {
    message: {
      token: deviceToken,
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: dataStr,
      android: {
        priority: "HIGH" as const,
        notification: { sound: "default" },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(message),
  });

  if (res.ok) {
    return { token: deviceToken, success: true };
  }

  // FCM v1 에러 응답 파싱
  const errJson = await res.json().catch(() => ({} as Record<string, unknown>));
  const errStatus =
    (errJson?.error as Record<string, unknown>)?.status as string | undefined;
  const errMessage =
    (errJson?.error as Record<string, unknown>)?.message as string | undefined;

  return {
    token: deviceToken,
    success: false,
    errorCode: errStatus ?? `HTTP_${res.status}`,
    errorMessage: errMessage ?? "unknown",
  };
}

// ─────────────────────────────────────────────────────────────
// Main handler
// ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  const preflight = handlePreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return error("method not allowed", 405);
  }

  // Webhook Secret 검증: 외부에서 임의 호출 차단.
  // DB Webhook 설정 시 Headers에 Authorization: Bearer <secret> 등록해야 함.
  const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
  if (expectedSecret) {
    const authHeader = req.headers.get("Authorization") ?? "";
    const provided = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (provided !== expectedSecret) {
      return error("unauthorized", 401);
    }
  }

  try {
    const payload = (await req.json()) as DbWebhookPayload;

    // DB Webhook payload 형태가 아니면 거부
    if (payload?.type !== "INSERT" || payload?.table !== "notifications") {
      return error("invalid webhook payload", 400);
    }

    const notification = payload.record;
    if (!notification?.id) {
      return error("missing notification id", 400);
    }

    // 이미 처리된 알림이면 중복 발송 방지
    if (notification.status !== "pending") {
      return json({ skipped: true, reason: "not pending" });
    }

    const supabase = serviceClient();

    // 1. 대상 사용자의 device_tokens 조회
    const { data: tokens, error: tokensErr } = await supabase
      .from("device_tokens")
      .select("fcm_token")
      .eq("user_id", notification.user_id);

    if (tokensErr) {
      await markFailed(supabase, notification.id, tokensErr.message);
      return error(`failed to load tokens: ${tokensErr.message}`, 500);
    }

    if (!tokens || tokens.length === 0) {
      await markFailed(supabase, notification.id, "no device tokens");
      return json({ sent: 0, reason: "no device tokens" });
    }

    // 2. Firebase Service Account 파싱
    const saJsonStr = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
    if (!saJsonStr) {
      await markFailed(supabase, notification.id, "FIREBASE_SERVICE_ACCOUNT_JSON env missing");
      return error("FIREBASE_SERVICE_ACCOUNT_JSON not configured", 500);
    }

    let sa: ServiceAccount;
    try {
      sa = JSON.parse(saJsonStr) as ServiceAccount;
    } catch (_e) {
      await markFailed(supabase, notification.id, "invalid service account JSON");
      return error("invalid service account JSON", 500);
    }

    // 3. Google access_token 발급
    let accessToken: string;
    try {
      accessToken = await getGoogleAccessToken(sa);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "unknown";
      await markFailed(supabase, notification.id, `oauth2: ${msg}`);
      return error(`oauth2 failure: ${msg}`, 500);
    }

    // 4. 각 디바이스 토큰에 병렬 발송
    const results = await Promise.all(
      tokens.map((t) =>
        sendFcm(sa.project_id, accessToken, t.fcm_token, notification)
      ),
    );

    // 5. 만료된 토큰 정리 (UNREGISTERED / NOT_FOUND)
    const staleTokens = results
      .filter((r) =>
        !r.success &&
        (r.errorCode === "UNREGISTERED" || r.errorCode === "NOT_FOUND")
      )
      .map((r) => r.token);

    if (staleTokens.length > 0) {
      await supabase
        .from("device_tokens")
        .delete()
        .in("fcm_token", staleTokens);
    }

    // 6. notifications 행 상태 업데이트
    const successCount = results.filter((r) => r.success).length;
    const failedCount = results.length - successCount;

    if (successCount > 0) {
      await supabase
        .from("notifications")
        .update({
          status: "sent",
          sent_at: new Date().toISOString(),
          error_message: failedCount > 0
            ? `partial: ${failedCount} failed`
            : null,
        })
        .eq("id", notification.id);
    } else {
      const firstErr = results[0];
      await markFailed(
        supabase,
        notification.id,
        `${firstErr.errorCode}: ${firstErr.errorMessage}`,
      );
    }

    return json({
      notification_id: notification.id,
      total_tokens: tokens.length,
      success: successCount,
      failed: failedCount,
      stale_removed: staleTokens.length,
      results,
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : "unknown";
    return error(msg, 500);
  }
});

async function markFailed(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  notificationId: string,
  message: string,
): Promise<void> {
  await supabase
    .from("notifications")
    .update({
      status: "failed",
      sent_at: new Date().toISOString(),
      error_message: message,
    })
    .eq("id", notificationId);
}
