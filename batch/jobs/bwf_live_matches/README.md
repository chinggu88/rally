# BWF Live Matches 워커

현재 라이브 중인 BWF 경기를 **10초 주기**로 폴링해 `bwf_live_matches`에 매치당 1행으로 upsert한다. 개인 PC에서 상주 실행하는 워커.

## 왜 이 구조인가 — 데이터 흐름 (2026-06 개편)

**진입점이 두 군데에서 한 군데로 단순화됐다.**

| 단계 | 이전 | 현재 |
|---|---|---|
| 1. 활성 대회 선택 | `bwfworldtour.../calendar/{year}/` SPA → `vue-current-live` 캡처 | **Supabase `bwf_tournaments`에서 `start_date ≤ today ≤ end_date` 필터** |
| 2. 라이브 매치 데이터 | 각 대회 `bwfworldtour.../tournament/{tid}/{slug}/results/{date}` 페이지 SPA 렌더 + DOM 스크래핑 | **`match-centre.bwfbadminton.com/{tid}` SPA → `vue-live-matches` JSON 캡처 한 방** |

활성 대회는 캘린더 잡이 이미 채워두는 테이블을 신뢰하면 되므로 캘린더 SPA 캡처 단계 자체가 불필요해졌다. 라이브 매치는 SPA가 호출하는 단일 JSON 엔드포인트가 DOM 스크래핑보다 훨씬 풍부한 데이터를 한 번에 준다(코트/duration/service_player/match_state 등).

### Cloudflare 우회는 여전히 필요

`extranet-lv.bwfbadminton.com/api/match-center/vue-live-matches`는 JA3 fingerprint 검사로 `requests`/`page.request`/`page.evaluate fetch` 모두 403. SPA가 자기 컨텍스트에서 호출한 응답만 200. 그래서 Playwright 페이지를 띄우고 `page.on('response')`로 가로채는 방식 그대로.

## 데이터 흐름

```
(워커 시작)  Playwright headless Chromium 띄움
                    │
                    ▼
   ┌──── 10초마다 ────────────────────────────┐
   │  ① bwf_tournaments에서 오늘 활성 대회 조회 (5분 캐시)    │
   │      │                                                   │
   │      ▼                                                   │
   │  ② 각 tid마다:                                            │
   │     page.goto("https://match-centre.bwfbadminton.com/{tid}") │
   │     SPA가 vue-live-matches를 자동 호출                    │
   │     page.on('response')가 JSON 가로챔                    │
   │      │                                                   │
   │      ▼                                                   │
   │  ③ parse_live_matches → bwf_live_matches rows           │
   │      │                                                   │
   │      ▼                                                   │
   │  ④ _hydrate_match_codes로 match_code(GUID) 채움          │
   │     (tid, event, 양 팀 선수 ID set) 4-튜플 룩업           │
   │      │                                                   │
   │      ▼                                                   │
   │  ⑤ upsert + mark_ended sweep                            │
   │      │                                                   │
   │      ▼                                                   │
   │  bwf_live_matches (Realtime publication enabled)        │
   │      │                                                   │
   │      ▼                                                   │
   │  Flutter .stream() → 라이브 매치 UI 자동 갱신            │
   └──────────────────────────────────────────────────────────┘
```

## 응답 스키마 (vue-live-matches)

```jsonc
{
  "results": [
    {
      "live_detail": {
        "id": 53278,
        "match_id": "203",                // = match_detail.code (대회 내 매치 번호)
        "match_state": "P",               // P=In Progress
        "match_state_name": "In Progress",
        "court_code": "1", "court_name": "Court 1",
        "duration": 12,                   // 분
        "event": "MD",                    // MS/WS/MD/WD/XD
        "round": "R32",
        "service_player": 3,              // 1..4 (어느 선수가 서브 중)
        "team1_g1_score": 13, "team1_g2_score": null, "team1_g3_score": null,
        "team2_g1_score": 21, "team2_g2_score": null, "team2_g3_score": null
      },
      "match_detail": {
        "id": 1525931,                    // = bwf_matches.id (사용자 검증 완료)
        "tournament_id": 5701, "code": "203",
        "team1_player1_id": "89743", "team1_player2_id": "94777",
        "team2_player1_id": "91710", "team2_player2_id": "82378",
        "t1p1_country": "USA", /* ... */
        "t1p1_player_model": { "name_display": "Ansen LIU", "slug": "...", "playerLink": "...", /* ... */ }
      }
    }
  ]
}
```

`match_state != "P"` 인 항목은 라이브로 취급하지 않고 파서에서 걸러진다(mark_ended가 청소).

## `bwf_live_matches` ↔ `bwf_matches` 연동 (match_code)

vue-live-matches는 BWF의 `match_code`(GUID)를 노출하지 않는다. `match_detail.id`는 `bwf_matches.id`와 동일 체계지만, 다운스트림(`bwf_matches`)의 PK는 GUID인 `match_code`이므로 4-튜플 룩업으로 채운다 — 같은 대회·종목 안에서 두 팀의 선수 ID 조합은 유일하다.

```sql
SELECT match_code FROM bwf_matches
 WHERE tournament_id = :tid
   AND event_name    = :event
   AND team1_player_ids @> ARRAY[:t1...]::bigint[]
   AND team2_player_ids @> ARRAY[:t2...]::bigint[];
```

팀 순서는 라이브 카드와 draw 데이터에서 뒤집혀 들어올 수 있어 양 팀을 `frozenset`으로 묶어 비교한다(순서 무관).

**upsert 시점 (`upsert_live_matches`)**
- 라이브 row를 쓰기 직전, 이번 틱에 등장한 `tournament_id` 집합으로 `bwf_matches`에서 `(match_code, tournament_id, event_name, team1_player_ids, team2_player_ids)`를 한 번에 SELECT (대회별 한 번).
- 4-튜플 키로 매칭해 라이브 row의 `match_code` 컬럼에 채워 upsert.
- `bwf_matches`에 아직 없는 매치는 None으로 남고, 다음 틱에서 재시도된다.

**종료 시점 (`mark_ended`, 소프트 삭제)**
1. 종료 후보(`tournament_status='live' AND promoted_at IS NULL`이고 이번 틱 active id에 없는 행)를 `id, match_code, score, tournament_id, event_name, team1_player_ids, team2_player_ids`로 SELECT.
2. `match_code`가 비어 있으면 위와 동일한 4-튜플 키로 `bwf_matches`에서 재룩업해 채움(upsert 시점에 못 가져온 케이스 보강).
3. `match_code` 기준으로 `bwf_matches.score`를 라이브 마지막 score로 UPDATE.
4. `bwf_live_matches`는 `promoted_at=now() + tournament_status='post'`로 소프트 삭제(히스토리/UX 보존, 다시 라이브로 잡히면 자연 복구).

`get-live-matches` Edge Function은 항상 `tournament_status='live'`만 반환하므로, 종료된 매치는 클라이언트에서 즉시 사라지고 score는 `bwf_matches`에서 영구 보관된다.

## sweep 안전망

- **vue-live-matches 캡처 실패 (`payload=None`)**: 해당 대회는 `polled_tournament_ids`에서 제외 → mark_ended sweep에서 빠진다(전역 폭주 방지).
- **응답은 받았지만 results 빈 배열**: 그 대회는 라이브 매치가 없다는 신호. polled에 포함돼 sweep이 그 대회 범위 내에서 정상 동작.
- **bwf_tournaments 조회 실패**: 이전 캐시를 그대로 재사용. 캐시가 비어 있으면 그 틱은 그냥 skip.

## CLI

```bash
source batch/.venv/bin/activate
pip install -r batch/requirements.txt
playwright install chromium

# 상주 (Ctrl+C로 종료 — batch_logs에 'stopped' 마킹)
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main

# 한 틱만 (개발/스모크)
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once

# DB 쓰기 없이 페이로드만 출력 (활성 대회 조회는 함)
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once --dry-run

# 브라우저 창 보면서 디버그
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once --headed
```

### 백그라운드 상주 / 종료

```bash
# 백그라운드로 상주 실행 (로그는 batch/jobs/bwf_live_matches/worker.log)
nohup env PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main \
  > batch/jobs/bwf_live_matches/worker.log 2>&1 &

# 실행 중인 프로세스 확인
ps aux | grep -i bwf_live_matches | grep -v grep

# 정상 종료 (batch_logs에 'stopped' 마킹)
pkill -TERM -f "batch.jobs.bwf_live_matches.main"

# 강제 종료 (SIGTERM 무시될 때만)
pkill -9 -f "batch.jobs.bwf_live_matches.main"
```

중복 실행 방지를 위해 새로 띄우기 전 항상 `ps`로 기존 프로세스를 먼저 확인한다.

## batch_logs

상주 워커라 매 틱마다 row를 박지 않는다:
- 시작 시 1회 `status='started'`
- 60분마다 `status='running'` + metadata heartbeat 갱신
- SIGINT/SIGTERM → `status='stopped'` + `finished_at`
- 치명적 에러 → `status='failed'`

## 검증

### 1. Dry-run 한 틱

```bash
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once --dry-run
```

오늘 활성 대회가 0건이면 `no active tournaments for today` 로그만, 1건 이상이면 각 매치의 정규화된 JSON을 stdout으로 떨군다.

### 2. 실 적재

```bash
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once
```

```sql
select id, tournament_id, name, event_name, round_name,
       team1_country, team2_country, score, court_name,
       tournament_status, promoted_at, last_polled_at
  from bwf_live_matches
 where tournament_status='live'
 order by last_polled_at desc;
```

### 3. Realtime 푸시 확인

```dart
supabase
  .from('bwf_live_matches')
  .stream(primaryKey: ['id'])
  .listen((rows) => print('pushed ${rows.length} live match(es)'));
```

워커가 첫 틱을 돌리는 순간 stream 콜백이 트리거된다.

## 알려진 제약 / 후속 작업

- **bwf_tournaments 의존**: 캘린더 잡이 활성 대회를 누락하면 라이브도 잡히지 않는다. 캘린더 잡 헬스 모니터링 권장.
- **개인 PC 의존**: 워커가 꺼지면 라이브가 끊긴다.
- **Cloudflare 차단 가능성**: IP가 차단되면 `page.goto` 자체가 챌린지에 막힌다. 그 경우 `playwright-stealth` 도입을 검토(이미 `batch/.venv`에 설치돼 있음).
