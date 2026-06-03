# BWF Live Tournaments 워커

현재 라이브 중인 BWF 대회 목록을 **10초 주기**로 폴링해 `bwf_live_tournaments`에 upsert한다. 개인 PC에서 상주 실행하는 워커.

> **메모**: 모듈 디렉터리 이름이 `bwf_live_matches`인 건 이전 설계의 흔적이다. 현재 구현은 라이브 **대회 목록**만 다루고 매치/스코어 단위는 다음 단계에서 다룬다.

## 왜 이 구조인가 — 진단 기록

2026-06 기준 BWF가 운영 API의 인증·전송 모델을 통째로 바꿨다:

| 항목 | 기존 (bwf_matches) | 현재 |
|---|---|---|
| 인증 | 페이지 HTML의 `token: "..."` 정규식 → Bearer 헤더 | 토큰 자체가 없음. 쿠키만 (`cf_clearance`, `laravel_session`) |
| 메서드 | POST + JSON body | **GET + query string** |
| Cloudflare | 일반 `requests` 통과 | **JA3 fingerprint 검사** — `requests`/`page.request`/`page.evaluate fetch` 모두 403 |
| 라이브 엔드포인트 | 없음 (캘린더 fetch + 필터링) | **`GET /api/match-center/vue-current-live`** 신규 |

그 결과 **유일하게 200을 받는 경로는 "SPA가 자기 컨텍스트에서 호출한 응답을 `page.on('response')`로 가로채기"** 한 가지뿐이다. 그래서 워커가 Playwright 페이지를 상주시킨다.

## 데이터 흐름

```
(워커 시작)  Playwright headless Chromium 띄움
                    │
                    ▼
   ┌──── 10초마다 ────────────────────────────┐
   │  page.goto("https://bwfworldtour.../calendar/2026/")     │
   │      │                                                   │
   │      ▼                                                   │
   │  SPA가 vue-current-live를 자동 호출                       │
   │      │                                                   │
   │      ▼                                                   │
   │  page.on('response')가 JSON 가로챔                       │
   │      │                                                   │
   │      ▼                                                   │
   │  parser.parse_live_payload → bwf_live_tournaments rows  │
   │      │                                                   │
   │      ▼                                                   │
   │  upsert(on_conflict=tournament_id) + mark_ended sweep    │
   │      │                                                   │
   │      ▼                                                   │
   │  bwf_live_tournaments (Realtime publication enabled)    │
   │      │                                                   │
   │      ▼                                                   │
   │  Flutter .stream() → 라이브 대회 목록 UI 자동 갱신       │
   └──────────────────────────────────────────────────────────┘
```

`bwf_live_tournaments`에 `REPLICA IDENTITY FULL` + `supabase_realtime` publication이 걸려있어 행 추가/`ended_at` 마킹/필드 변경이 Flutter에 푸시된다 (마이그레이션: [`20260602130000_bwf_live_tournaments.sql`](../../../supabase/migrations/20260602130000_bwf_live_tournaments.sql)).

## 응답 스키마 (vue-current-live)

```json
{
  "results": [
    {
      "id": 5528,
      "code": "5A719D43-A131-43FC-9A7F-BAFBC0B551E8",
      "name": "POLYTRON Indonesia Open 2026",
      "slug": "polytron-indonesia-open-2026",
      "start_date": "2026-06-02 00:00:00",
      "end_date": "2026-06-07 00:00:00",
      "tournament_category_id": 23,
      "tournament_series_id": 64,
      "prize_money": "1450000.00",
      "venue_name": "Istora Senayan Jakarta",
      "date": "2 - 7 June",
      "tmtLink": "https://bwfworldtour.bwfbadminton.com/tournament/5528/polytron-indonesia-open-2026/results/",
      "tmtLogo": "https://...",
      "category_model": {"id": 23, "name": "HSBC BWF World Tour Super 1000"}
    }
  ]
}
```

대회별로 한 row가 `bwf_live_tournaments`에 upsert된다.

## `ended_at` 처리

라이브 응답에 더 이상 안 보이는 대회는 **삭제하지 않고 `ended_at`을 박는다**:
- 히스토리/UX 보존 (방금 끝난 대회를 잠깐 더 보여줄 수 있음)
- 캘린더 잡(현재 동일한 BWF API 변경으로 깨져있음, 추후 수정) 정상화 후 `bwf_matches`로 최종 결과 이관

`payload=None`(캡처 실패)일 때는 sweep을 **스킵**한다 — 일시적 네트워크/Cloudflare 이슈로 전 대회를 종료 처리하는 사고 방지.

## `bwf_live_matches` ↔ `bwf_matches` 연동 (match_code)

라이브 카드(results 페이지) 자체에는 BWF의 `match_code`(GUID)가 노출되지 않는다. **추가로 카드 href의 `/match/{id}`와 `bwf_matches.id`는 서로 다른 ID 체계라서 id 조인이 불가하다.** 대신 라이브 워커는 **`(tournament_id, event_name, team1_player_ids set, team2_player_ids set)`** 4-튜플로 `bwf_matches`를 룩업한다 — 같은 대회·종목 안에서 두 팀의 선수 ID 조합은 유일하다(아래 확인 SQL과 동일한 키).

```sql
-- 라이브 카드 한 장에 대응하는 bwf_matches row 찾기
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

## CLI

```bash
source batch/.venv/bin/activate
pip install -r batch/requirements.txt
playwright install chromium

# 상주 (Ctrl+C로 종료 — batch_logs에 'stopped' 마킹)
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main

# 한 틱만 (개발/스모크)
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once

# DB 쓰기 없이 페이로드만 출력
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once --dry-run

# 브라우저 창 보면서 디버그
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once --headed
```

## batch_logs

상주 워커라 매 틱마다 row를 박지 않는다:
- 시작 시 1회 `status='started'`
- 60분마다 `status='running'` + metadata heartbeat 갱신
- SIGINT/SIGTERM → `status='stopped'` + `finished_at`
- 치명적 에러 → `status='failed'`

## 검증

### 1. 마이그레이션 적용

```bash
supabase db push
```

```sql
\d bwf_live_tournaments
select pubname, tablename from pg_publication_tables where tablename='bwf_live_tournaments';
select relname, relreplident from pg_class where relname='bwf_live_tournaments';
-- relreplident = 'f' (FULL)
```

### 2. Dry-run 한 틱

```bash
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once --dry-run
```

라이브 대회가 0건이면 빈 배열 출력, 1건 이상이면 샘플 JSON이 stdout으로 떨어진다.

### 3. 실 적재

```bash
PYTHONPATH=. python -m batch.jobs.bwf_live_matches.main --once
```

```sql
select tournament_id, name, start_date, end_date,
       first_seen_at, last_seen_at, ended_at
  from bwf_live_tournaments
 order by last_seen_at desc;
```

### 4. ended_at sweep 동작

라이브 응답에 없는 대회를 만들어 sweep 테스트:

```sql
-- 가짜 라이브 대회 삽입 (응답에 없는 id)
insert into bwf_live_tournaments (tournament_id, code, name)
values (99999, 'TEST-GUID', 'TEST FAKE');
```

다음 틱 후:

```sql
select tournament_id, ended_at from bwf_live_tournaments where tournament_id=99999;
-- ended_at이 not null이어야 함
```

### 5. Realtime 푸시 확인

Flutter:

```dart
supabase
  .from('bwf_live_tournaments')
  .stream(primaryKey: ['tournament_id'])
  .listen((rows) => print('pushed ${rows.length} live tournament(s)'));
```

워커가 첫 틱을 돌리는 순간 stream 콜백이 트리거된다.

## 알려진 제약 / 후속 작업

- **매치/스코어 단위 미구현**: vue-current-live는 라이브 **대회 목록**만 반환한다. 매치 데이터는 SPA가 사용자 클릭에 반응해서 호출하는 다른 엔드포인트를 추가 조사해야 한다 (`/api/tournaments/draws?tournament_code={GUID}`까지는 확인됨, 종목별 매치 엔드포인트는 미확인).
- **기존 `bwf_matches`/`bwf_rankings`/`bwf_calendar` 잡 동시 장애**: 같은 BWF API 변경(토큰 제거, POST→GET)으로 모두 깨졌을 가능성이 높다. 현재 작업에서는 손대지 않음 — 별도 작업으로 마이그레이션 필요.
- **개인 PC 의존**: 워커가 꺼지면 라이브가 끊긴다.
- **Cloudflare 차단 가능성**: IP가 차단되면 `page.goto` 자체가 챌린지에 막힌다. 그 경우 `playwright-stealth` 도입을 검토(이미 `batch/.venv`에 설치돼 있음).
- **카테고리 좁아짐**: SPA가 호출하는 카테고리 목록이 `[22..26]`으로 줄었다. Finals(20), 1000(21), Super 100/Team(27 등)이 포함되는지는 그 카테고리가 실제 라이브일 때 확인 필요.
