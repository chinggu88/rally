# Ranking Notifier — 관심선수 랭킹 변화 푸시 알림

매주 갱신되는 `bwf_rankings` 결과에서 순위 변동이 있는 선수를 감지하여, 해당 선수를 관심등록한 사용자에게 FCM 푸시를 보낸다.

## 파이프라인

```
bwf_rankings 잡 완료
  ↓ (같은 프로세스에서 자동 호출)
ranking_notifier.main.run(year, week)
  ↓
1. bwf_rankings 에서 rank_change != 0 row 조회
2. member_id → player_id 리스트 분해
     · 단식: "12345"        → [12345]
     · 복식: "12345-67890"  → [12345, 67890]   (둘 중 한 명만 등록되어 있어도 발송)
3. favorite_players JOIN profiles(notifications_enabled=true)
4. 같은 주(year/week) + 같은 member_id 로 이미 알림 받은 user 제외
5. notifications 테이블에 status='pending' 으로 insert
  ↓ (DB Webhook)
supabase/functions/send-push
  ↓
device_tokens 조회 → FCM v1 send → notifications.status 업데이트
```

## 안내 멘트 예시

```
📈 관심선수 랭킹 상승
LEE Hyun Il (남자 단식)
세계랭킹 3계단 상승 → 현재 5위
```

```
📉 관심선수 랭킹 하락
KIM Won Ho / SEO Seung Jae (남자 복식)
세계랭킹 4계단 하락 → 현재 12위
```

## 알림 페이로드 (notifications.data JSONB)

| key | 예시 | 용도 |
|---|---|---|
| `type` | `"ranking_change"` | 클라이언트 라우팅 / 중복 체크 |
| `category` | `"MS"` | MS/WS/MD/WD/XD |
| `member_id` | `"12345"` 또는 `"12345-67890"` | 중복 체크 키 |
| `rank` | `"5"` | 현재 순위 (FCM data는 string only) |
| `rank_change` | `"3"` / `"-4"` | 변동 폭/방향 |
| `ranking_year` | `"2026"` | 중복 체크 키 |
| `ranking_week` | `"20"` | 중복 체크 키 |

## 실행

자동 (운영):
- `bwf_rankings` 잡 완료 직후 자동 호출 — 매주 월요일 08:40 KST
- 실패해도 `bwf_rankings` 잡 자체는 success 처리됨 (격리된 try/except)

수동:
```bash
# 최근 주 자동 감지
python -m batch.jobs.ranking_notifier.main

# 특정 주 지정 (Python REPL)
from batch.jobs.ranking_notifier.main import run
run(year=2026, week=20)
```

## 중복 방지

같은 주(`ranking_year`+`ranking_week`) + 같은 `member_id` 조합으로 이미 `notifications` 행이 있으면 해당 user는 skip.
→ 배치가 재실행되거나 한 주에 두 번 돌아도 같은 사용자에게 중복 푸시되지 않음.

## 의존 테이블

| 테이블 | 용도 |
|---|---|
| `bwf_rankings` | `rank_change != 0` row 조회 |
| `favorite_players` | `player_id` 로 관심 유저 조회 |
| `profiles` | `notifications_enabled = true` 인 유저만 |
| `notifications` | 발송 큐 — 여기 insert 하면 send-push 가 자동 실행 |

## 모니터링

- `batch_logs` 테이블 `job='ranking_notifier'` 행 metadata:
  - `changed_rankings` — 이번 주 변동된 랭킹 수
  - `notifications_inserted` — 실제 insert 된 알림 수
  - `unique_users` — 푸시 대상 고유 사용자 수
  - `skipped_duplicate` — 중복 발송 방지로 skip 된 수

## 테스트

```bash
python3 -m pytest batch/tests/test_ranking_notifier.py -v
```
