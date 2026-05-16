# BWF World Rankings 크롤링

BWF(Badminton World Federation) 세계 랭킹 5개 종목(MS/WS/MD/WD/XD)을 매주 월요일 페치하여 `bwf_rankings` 테이블에 upsert.

## 데이터 소스 (사이트가 아닌 내부 API)

BWF 랭킹 페이지는 Vue.js로 동작하며 실제 데이터는 다음 API에서 옵니다:

- **Base**: `https://extranet-lv.bwfbadminton.com`
- **랭킹 주차 목록**: `POST /api/vue-rankingweek` (body: `{rankId: 2}`)
- **랭킹 테이블**: `POST /api/vue-rankingtable` (페이지네이션 응답)

진입 페이지 `https://bwfbadminton.com/rankings/`에 Bearer 토큰이 인라인 임베드되어 있어, Playwright로 페이지를 로드해 토큰을 추출한 뒤 `requests`로 API를 직접 호출합니다 (Cloudflare는 진입 페이지에만 걸려있음).

### catId 매핑 (BWF World Rankings: rankId=2)

| 종목 | catId |
|---|---|
| MS | 6 |
| WS | 7 |
| MD | 8 |
| WD | 9 |
| XD | 10 |

### 페이지네이션

응답에 `current_page`, `last_page`, `total`, `per_page` 포함. `pageKey="1000"`로 페이지당 1000개씩 받음 — 종목당 2~3페이지로 끝남.

## 추출 필드

응답 JSON에서 추출:

| 컬럼 | 출처 |
|---|---|
| `rank` | `row.rank` |
| `points` | `row.points` |
| `tournaments` | `row.tournaments` |
| `player_name` | `player1_model.name_display` (복식은 ` / ` 결합) |
| `member_id` | `player1.id` (복식은 `id1-id2`) |
| `country_code` | `p1_country_model.code_iso3` |
| `country_name` | `p1_country_model.name` |

## 로컬 실행

```bash
# 프로젝트 루트에서
source batch/.venv/bin/activate
pip install -r batch/requirements.txt
playwright install chromium

cp batch/.env.example batch/.env
# batch/.env에 SUPABASE_SERVICE_KEY 입력 후

PYTHONPATH=. python -m batch.jobs.bwf_rankings.main
```

## 적재 전략

- 키: `(category, member_id)` UNIQUE
- 매주 동일 키에 대해 덮어쓰기 (upsert)
- 청크 단위 500개씩 분할 + 청크 내 dedupe (같은 키가 한 청크에 두 번 오면 더 낮은 rank 유지)

## 실행 로그

`batch_logs` 테이블에 시작/종료/에러 기록:
```sql
select * from batch_logs where job = 'bwf_rankings'
order by started_at desc limit 5;
```

## 스케줄

[`.github/workflows/batch-bwf-rankings.yml`](../../../.github/workflows/batch-bwf-rankings.yml) — 매주 월요일 00:00 UTC (09:00 KST).

## 알려진 위험

- BWF가 API 토큰 발급 방식을 바꾸면 `extract_api_token` 정규식 깨짐
- Cloudflare가 GitHub Actions IP를 차단할 가능성 → 차단 시 `playwright-stealth` 또는 프록시 추가
- 토큰이 페이지에 인라인 임베드 → 만료/회전 시 매 실행마다 재추출하므로 큰 문제는 아님
