# Live Activity (잠금화면 + 다이나믹 아일랜드) 설정

코드는 전부 작성·빌드 검증 완료다. 아래는 **사람이 해야 하는 설정**만 남긴 것이다.

## 무엇이 만들어졌나

| 위치 | 역할 |
|---|---|
| `ios/Shared/RallyMatchAttributes.swift` | Activity 속성/상태 정의 (Runner + 위젯 타겟 공유) |
| `ios/RallyWidget/RallyLiveActivity.swift` | 잠금화면 카드 + 다이나믹 아일랜드 UI |
| `ios/Runner/LiveActivityBridge.swift` | Flutter ↔ ActivityKit 브리지, push token 수집 |
| `lib/services/live_activity_service.dart` | Dart 제어 + 토큰 서버 저장 |
| `supabase/functions/send-live-activity/` | APNs 직접 전송 (ES256 JWT) |
| `live_activity_tokens` / `live_activity_events` | 토큰 보관 / 전송 큐 (적용 완료) |

다이나믹 아일랜드는 **iPhone 14 Pro 이상 + iOS 16.1+** 에서만 보인다.
그 외 기기는 같은 Activity가 잠금화면 카드로만 표시된다(코드는 동일).

---

## 1. APNs 인증키(.p8) 발급 — 필수

Live Activity는 FCM을 경유할 수 없어 **APNs로 직접** 쏴야 한다.

1. https://developer.apple.com/account/resources/authkeys/list
2. **Keys > +** → 이름 입력 → **Apple Push Notifications service (APNs)** 체크 → Continue → Register
3. `.p8` 파일을 내려받는다 (**한 번만 받을 수 있다 — 잃어버리면 재발급**)
4. **Key ID**(10자)를 적어둔다. **Team ID**는 `46UWPJPL54`.

## 2. Edge Function secrets 등록

```bash
supabase secrets set \
  APNS_KEY_P8="$(cat AuthKey_XXXXXXXXXX.p8)" \
  APNS_KEY_ID=XXXXXXXXXX \
  APNS_TEAM_ID=46UWPJPL54 \
  APNS_BUNDLE_ID=com.iksun.rallys \
  APNS_ENV=sandbox
```

`APNS_ENV`는 `ios/Runner/Runner.entitlements`의 `aps-environment`와 맞춰야 한다.
현재 `development` → `sandbox`. TestFlight/App Store 배포 시 **둘 다** production으로 바꾼다.

## 3. Edge Function 배포

```bash
supabase functions deploy send-live-activity
```

## 4. DB Webhook 연결 — 필수

기존 `send-push-on-notification`과 같은 방식이다.
Supabase 대시보드 > **Database > Webhooks > Create a new hook**

| 항목 | 값 |
|---|---|
| Name | `send-live-activity-on-event` |
| Table | `public.live_activity_events` |
| Events | **Insert** 만 |
| Type | HTTP Request |
| URL | `https://ztcfgymcxilxcjahyucw.supabase.co/functions/v1/send-live-activity` |
| Method | POST |
| Headers | `Content-type: application/json` |
| Timeout | 5000 |

> 이 웹훅이 없으면 큐(`live_activity_events`)에 행만 쌓이고 푸시는 나가지 않는다.

## 5. 확인

1. 앱 실행 → 홈 "오늘 경기"에서 **진행 중인 경기**의 별을 탭
2. 잠금화면에 카드가 뜨는지 / iPhone 14 Pro 이상이면 다이나믹 아일랜드에 스코어가 뜨는지
3. 다이나믹 아일랜드를 **길게 눌러** 확장 뷰(선수명 + 세트 칩) 확인
4. **앱을 완전히 종료**한 뒤 점수가 바뀔 때 따라 움직이는지 → 이게 APNs 경로 검증이다

라이브 경기가 없는 시간대면 대시보드에서 해당 `bwf_live_matches` 행의 `score`를
직접 UPDATE한다. score는 **jsonb 배열**이다:

```json
[{"set":1,"home":21,"away":17},{"set":2,"home":19,"away":21},{"set":3,"home":18,"away":14}]
```

전송 결과는 `live_activity_events`의 `status` / `error_message`에서 확인한다.

---

## 동작 설계 메모

- **10초 폴링 노이즈 차단**: 배치 워커가 `bwf_live_matches`를 10초마다 upsert하므로,
  트리거가 `score`/`match_status`/`tournament_status` 변화가 있을 때만 큐에 넣는다.
  (`last_polled_at`은 비교 대상에서 제외.) 검증 완료 — 폴링만으로는 큐가 생기지 않는다.
- **APNs JWT 캐시**: 45분 재사용. 매번 새로 만들면 `TooManyProviderTokenUpdates(429)`.
- **토큰 정리**: APNs 410(Gone) 응답이면 삭제하고, 경기 종료 시 해당 경기 토큰을 모두 정리한다.
- **포그라운드**: Realtime으로 받은 스코어는 푸시 왕복 없이 `update`로 즉시 반영한다.
- **Activity 동시 1개**: 다른 경기를 지정하면 이전 Activity를 종료한다.
- **score 형태 주의**: `bwf_live_matches.score`는 문자열이 아니라 jsonb 배열
  `[{"set":1,"home":21,"away":14}]`이다 (home=team1, away=team2).
