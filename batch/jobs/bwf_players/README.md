# BWF Players 프로필 수집

`bwf_rankings` 테이블의 모든 선수에 대해 BWF 내부 API로 프로필을 수집하여 `bwf_players` 테이블에 upsert.

## 데이터 소스 (HTML 아님 — 내부 API)

선수 디테일 **HTML 페이지**(`https://bwfbadminton.com/player/{id}/`)는 Cloudflare 봇 차단 뒤에 있어 헤드리스 크롤링이 "Sorry, you have been blocked"로 막힌다. 대신 `bwf_rankings` 배치와 동일하게 **랭킹 진입 페이지에서 토큰을 한 번 추출**한 뒤, 선수 페이지가 실제로 호출하는 내부 API를 직접 `requests`로 부른다 (Cloudflare 미적용):

- **Base**: `https://extranet-lv.bwfbadminton.com`
- **요약**: `POST /api/vue-player-summary` body `{drawCount:1, playerId:"57945", isPara:false}` — 핵심 프로필 + `bio_model` + `avatar`
- **바이오**: `POST /api/vue-player-bio` body `{activeTab:1, playerId:"57945"}` — age, hand, prize_money, social (보조)

> 입력 player_id는 `bwf_rankings.player{1,2}_id`(없으면 `detail_url`에서 파싱)에서 가져온다.

## 아키텍처

```
fetcher.py     토큰 추출 + URL/ID 수집 + 두 API 호출
parser.py      API JSON → bwf_players 레코드
upserter.py    청크(200) 단위 upsert
main.py        오케스트레이션, batch_logs 기록, 진행률 로깅
```

## 추출 필드

| 컬럼 | 소스 |
|---|---|
| `id` | summary.id |
| `name_display` | summary.name_display (fallback `Player {id}`) |
| `first_name` / `last_name` | summary.first_name / last_name |
| `gender` | summary.gender_id (1→M, 2→F) |
| `country_code` / `country_name` | summary.country_model.code_iso3 / name |
| `birthday` | summary.date_of_birth (`YYYY-MM-DD HH:MM:SS`) |
| `height_cm` | summary.bio_model.height (또는 bio.height) |
| `handedness` | bio.hand (R→right, L→left, A→ambidextrous) |
| `photo_url` | summary.avatar.url_cloudinary (또는 원본 이미지) |
| `bio` | summary.bio_model.bwf_bio |
| `coach`, `birthplace`(pob), `plays` | summary.bio_model.* |
| `career_titles`, `career_wins`, `career_losses` | summary.* (있을 때만) |
| `social_links` | bio_model의 instagram/twitter/facebook/youtube/website + bio.social → jsonb |
| `detail_url` | bwf_rankings의 원본 URL |
| `raw` | `{summary, bio}` 원본 JSON 전체 |
| `detail_fetched_at` | UTC ISO timestamp |

> 모든 enrichment 필드는 nullable. API에 값이 없으면 null로 들어가고 `id`/`name_display`/`detail_url`은 항상 채워진다.

## 적재 전략

- 키: `id` (PK), `on_conflict="id"` upsert → 매번 덮어쓰기
- 청크 200개, 100개마다 진행률 로그
- 요청 간 0.3-0.7초 delay (API라 차단은 없지만 서버 예의 차원)
- 연속 15회 실패 시 전체 중단 (토큰 만료/API 변경 신호) + `status="failed"`

## 결과 분류

| status | 조건 |
|---|---|
| `success` | fetched / total ≥ 80% |
| `partial` | fetched / total < 80% |
| `failed`  | 예외로 중단 |

## 로컬 실행

```bash
# 프로젝트 루트에서
source batch/.venv/bin/activate
pip install -r batch/requirements.txt
playwright install chromium   # 토큰 추출용으로만 사용

# batch/.env에 SUPABASE_SERVICE_KEY 입력
PYTHONPATH=. python -m batch.jobs.bwf_players.main
```

## 단일 선수 probe

```bash
PYTHONPATH=. python batch/scripts/probe_player.py 57945
```

## 실행 로그 조회

```sql
select status, rows_written, finished_at - started_at as duration, metadata
  from batch_logs
 where job = 'bwf_players'
 order by started_at desc
 limit 5;
```

## 데이터 품질 확인

```sql
select
  count(*) as total,
  count(birthday) as has_birthday,
  count(height_cm) as has_height,
  count(handedness) as has_handedness,
  count(photo_url) as has_photo,
  count(*) filter (where social_links != '{}'::jsonb) as has_social
from bwf_players;
```

## 스케줄

[`.github/workflows/batch-bwf-players.yml`](../../../.github/workflows/batch-bwf-players.yml) — `workflow_dispatch`로 수동 실행만.
`bwf_rankings` 배치가 끝난 뒤 GitHub Actions UI에서 "Run workflow"로 실행.

## 알려진 위험

| 위험 | 영향 | 완화 |
|---|---|---|
| BWF 토큰 발급 방식 변경 | 토큰 추출 실패 | `bwf_rankings`와 공유하는 패턴 — 동시 갱신 필요 |
| player API 스키마/경로 변경 | 일부 필드 NULL 또는 fetch 실패 | nullable 컬럼 + `raw`에 원본 보존, 연속 실패 시 조기 중단 |
| 1000명 처리 시간 ~10분 | GitHub Actions 비용 | 워크플로 타임아웃 60분 |
| 일부 선수 bio 데이터 비어있음 | bio/coach/career 등 NULL | 정상 — BWF가 채우지 않은 데이터 |
