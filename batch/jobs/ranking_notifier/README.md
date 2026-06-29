# Ranking Notifier — 관심선수 랭킹 변화 푸시 알림

매주 갱신되는 `bwf_rankings` 결과에서 순위 변동이 있는 선수를 감지하여, 해당 선수를 관심등록한 사용자에게 FCM 푸시를 보낸다.
**유저당 그 주 1건의 요약 알림**만 발송하고(관심선수가 여러 명 변동해도 푸시는 1번), 선수별 상세 변동 내역은 `data.changes` 배열에 담아 앱 알림 화면에서 펼쳐 확인한다.

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
   → 유저별로 관심선수 변동 내역(changes)을 누적
4. 같은 주(year/week)에 이미 요약 알림 받은 user 제외 (유저 단위 중복방지)
5. 유저당 요약 알림 1건을 notifications 테이블에 status='pending' 으로 insert
  ↓ (DB Webhook)
supabase/functions/send-push
  ↓
device_tokens 조회 → FCM v1 send → notifications.status 업데이트
```

## 안내 멘트 (요약 푸시 — 모든 유저 공통)

```
📊 관심선수 랭킹 변동
관심선수의 세계랭킹이 변동했어요. 눌러서 확인하세요.
```

선수별 상세(상승/하락·계단 수·현재 순위)는 앱 알림 목록 항목을 탭하면 인라인으로 펼쳐 표시된다.

## 알림 페이로드 (notifications.data JSONB)

| key | 예시 | 용도 |
|---|---|---|
| `type` | `"ranking_change"` | 클라이언트 라우팅 / 중복 체크 |
| `ranking_year` | `"2026"` | 중복 체크 키 (user+year+week) |
| `ranking_week` | `"20"` | 중복 체크 키 (user+year+week) |
| `count` | `4` | 변동된 관심선수 수 |
| `changes` | `[{member_id, player_name, category, rank, rank_change}, ...]` | 선수별 상세 (앱에서 펼쳐 표시) |

`changes[]` 원소: `member_id`(단식/복식 식별자), `player_name`, `category`(MS/WS/MD/WD/XD), `rank`(현재 순위, int), `rank_change`(변동 폭/방향, int).

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

같은 주(`ranking_year`+`ranking_week`)에 이미 요약 알림 행이 있는 user는 skip (유저 단위).
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
