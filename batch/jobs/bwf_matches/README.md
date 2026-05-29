# BWF Matches 상세(경기) 수집

올해 캘린더의 각 대회 상세 페이지가 호출하는 내부 API로 **경기(matches) 데이터**를 수집하여 `bwf_matches` 테이블에 upsert. 대회를 **대회전 / 대회중 / 대회후** 로 분류해 함께 저장한다.

## 데이터 소스 (HTML 아님 — 내부 API)

대회 상세 페이지(`https://bwfworldtour.bwfbadminton.com/tournament/{id}/.../draws/`)는 Cloudflare 뒤의 SPA라 HTML 크롤링이 막힌다. 대신 `bwf_rankings`/`bwf_players`와 동일하게 **랭킹 진입 페이지에서 토큰을 한 번만 추출**한 뒤, SPA가 실제로 호출하는 내부 API를 직접 `requests`로 부른다.

- **Base**: `https://extranet-lv.bwfbadminton.com`
- **캘린더**: `POST /api/vue-grouped-year-tournaments` body `{year, category:[20..27]}` — 대회 목록 + `live_status`
- **대회 드로 목록**: `POST /api/vue-tournament-draws` body `{tmtTab:"draw", tmtId}` — 종목별(MS/WS/MD/WD/XD) `value`(=drawId)
- **드로 경기 데이터**: `POST /api/vue-tournament-draw-data` body `{tmtTab:"draw", tmtId, drawId}` — `matches` 배열 (★ 핵심)

> `drawId`는 대회마다 다르다(예: Malaysia MS=1, Singapore MS=3). 절대 하드코딩하지 말고 `vue-tournament-draws`의 `value`에서 매번 읽는다.

## 대회 상태 분류 (대회전/대회중/대회후)

캘린더 `live_status` → 3-state로 정규화:

| live_status | 분류 | 설명 |
|---|---|---|
| `future` / `pre` | **`pre`** (대회전) | 드로가 발표되면 경기는 있으나 `matchStatusValue="none"` (미진행). 드로 미발표면 경기 0건 |
| `live` | **`live`** (대회중) | `Finished` + `none` 혼재 |
| `post` / `completed` | **`post`** (대회후) | 전 경기 `Finished` |

각 경기 row의 `tournament_status` 컬럼에 크롤 시점 스냅샷으로 저장된다.

## 아키텍처

```
fetcher.py     토큰 추출 + 캘린더/드로/경기 3단 API 호출
parser.py      match JSON → bwf_matches 레코드 + live_status 정규화
upserter.py    청크(200) 단위 upsert (on_conflict=id)
main.py        오케스트레이션, batch_logs 기록, 진행률 로깅
```

## 추출 필드 (주요)

| 컬럼 | 소스 |
|---|---|
| `id` | match.id (안정적 PK) |
| `match_code` | match.code |
| `tournament_id` / `tournament_code` | 대회 id / GUID |
| `tournament_status` | live_status 정규화 (pre/live/post) |
| `draw_id` / `draw_code` / `event_name` | drawId / match.drawCode / MS·WS·MD·WD·XD |
| `match_type` / `round_name` | match.matchTypeValue / roundName (R32, QF, SF, F…) |
| `match_status` / `match_status_value` | F·none… / Finished·none… |
| `score_status` / `score_status_value` | 0=Normal / Walkover·Retired… |
| `winner` | 1·2·NULL |
| `team{1,2}_country` | 팀 국가코드 |
| `team{1,2}_player_ids` | 선수 id 배열 (단식 1, 복식 2) |
| `team{1,2}_names` | nameDisplay 배열 |
| `team{1,2}_seed` | 시드 |
| `score` | `[{set, home, away}, ...]` jsonb |
| `match_time` / `match_time_utc` | 현지 / UTC |
| `duration_min` / `court_name` / `location_name` | 경기 시간 / 코트 / 장소 |
| `raw` | match 원본 JSON 전체 |

> 모든 필드 nullable. `id`만 항상 채워지며, 없으면 그 경기는 스킵한다.

## 적재 전략

- 키: `id` (PK), `on_conflict="id"` upsert → 매번 덮어쓰기 (점수/상태 갱신)
- 청크 200개, 500개마다 flush
- 드로 호출 간 0.3-0.7초 delay
- 연속 15회 실패 시 전체 중단 (토큰 만료/API 변경 신호) + `status="failed"`

## 로컬 실행

```bash
source batch/.venv/bin/activate
pip install -r batch/requirements.txt
playwright install chromium   # 토큰 추출용으로만 사용

# 올해 전체
PYTHONPATH=. python -m batch.jobs.bwf_matches.main

# 특정 연도 / 단일 대회 / 미적재 미리보기
PYTHONPATH=. python -m batch.jobs.bwf_matches.main --year 2026
PYTHONPATH=. python -m batch.jobs.bwf_matches.main --tournament-id 5227
PYTHONPATH=. python -m batch.jobs.bwf_matches.main --dry-run

# 스모크 테스트: 앞 N개 대회만
BWF_MATCHES_LIMIT=3 PYTHONPATH=. python -m batch.jobs.bwf_matches.main --dry-run
```

## 단일 대회 probe

```bash
PYTHONPATH=. python batch/scripts/probe_matches.py 5227
```

## bwf_tournaments 와의 연결

`bwf_matches.tournament_id` → `bwf_tournaments.tournament_id` **외래키**로 연결된다 (BWF 대회번호 기준, `on delete cascade`, deferrable). `bwf_tournaments.tournament_id`가 UNIQUE라 FK 타깃이 된다.

> 전제: 캘린더 잡(`bwf_calendar`)이 matches가 참조할 수 있는 모든 category(Super 100 / Team / Individual 포함)를 적재해야 한다. 그래서 `tour_level`은 enum이 아닌 **text**다. matches 실행 전 캘린더 잡이 먼저 돌아야 FK 위반이 없다.

```sql
-- 조인
select t.name, t.tour_level, m.event_name, m.round_name,
       m.team1_names, m.team2_names, m.score
  from bwf_matches m
  join bwf_tournaments t on t.tournament_id = m.tournament_id
 where t.year = 2026 and m.round_name = 'Final';
```

PostgREST 임베딩도 가능:
- `bwf_matches?select=*,bwf_tournaments(name,tour_level)`
- `bwf_tournaments?select=*,bwf_matches(count)`

## 데이터 품질 확인

```sql
select tournament_status, count(*) as matches,
       count(*) filter (where match_status_value = 'Finished') as finished,
       count(*) filter (where match_status_value = 'none') as not_played
  from bwf_matches
 group by tournament_status;
```

## 스케줄

[`.github/workflows/batch-bwf-matches.yml`](../../../.github/workflows/batch-bwf-matches.yml) — `workflow_dispatch`(수동) + 매일 1회. 진행 중인 대회의 점수를 갱신하려면 대회 기간 동안 더 자주 실행.

## 알려진 위험

| 위험 | 영향 | 완화 |
|---|---|---|
| BWF 토큰 발급 방식 변경 | 토큰 추출 실패 | rankings/players와 공유 패턴 — 동시 갱신 |
| draw-data API 스키마/경로 변경 | fetch 실패 또는 필드 NULL | nullable 컬럼 + `raw` 보존, 연속 실패 시 조기 중단 |
| drawId 대회별 상이 | 잘못된 드로 조회 | `vue-tournament-draws`의 `value`에서 매번 동적 조회 |
| 대회중 라이브 점수 지연 | `score` 일시적 불일치 | upsert로 다음 실행 시 자동 보정 |
