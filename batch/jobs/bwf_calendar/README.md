# BWF Calendar — HSBC World Tour 크롤링

BWF 캘린더에서 **HSBC BWF World Tour 5개 등급** (Finals + Super 1000/750/500/300) 토너먼트를 매 실행마다 페치해 `bwf_tournaments` 테이블에 upsert.

## 데이터 소스

[bwf_rankings](../bwf_rankings/README.md)와 같은 내부 Vue API 패턴을 사용합니다:

- 진입: `https://bwfbadminton.com/calendar/` (Cloudflare → Playwright + stealth로 토큰만 추출)
- 본 API: `POST https://extranet-lv.bwfbadminton.com/api/vue-grouped-year-tournaments`
  - Body: `{"year": YYYY, "category": [8, 9, 10, 11, 12]}`
  - 응답: `{"results": [...], "remaining": [...], "completed": [...]}` — 본 작업은 **`results`만 사용** (1월~12월 전체)

### catId 매핑 (검증됨, `/api/vue-tournament-categories`)

| 등급 | catId | enum |
|---|---|---|
| HSBC BWF World Tour Finals | 8 | `FINALS` |
| HSBC BWF World Tour Super 1000 | 9 | `SUPER_1000` |
| HSBC BWF World Tour Super 750 | 10 | `SUPER_750` |
| HSBC BWF World Tour Super 500 | 11 | `SUPER_500` |
| HSBC BWF World Tour Super 300 | 12 | `SUPER_300` |

## 추출 필드

| 컬럼 | 출처 |
|---|---|
| `tournament_id` | `t.id` (UNIQUE 키) |
| `code` | `t.code` (UUID 문자열) |
| `name` | `t.name` |
| `tour_level` | `t.category` → enum 매핑 |
| `category_id` | `t.category` |
| `start_date`, `end_date` | `t.start_date/end_date`의 date 부분만 |
| `date_label` | `t.date` ("06 - 11 Jan" 원문) |
| `country`, `location` | `t.country`, `t.location` |
| `prize_money_usd` | `t.prize_money` 콤마 제거 후 float |
| `detail_url`, `flag_url`, `logo_url`, `cat_logo_url` | URL들 |
| `status`, `has_live_scores` | 상태 |
| `year` | CLI/기본값 |
| `raw` | 원본 토너먼트 JSON 전체 |

## 로컬 실행

```bash
./batch/run-bwf-calendar.sh                # 현재 연도
./batch/run-bwf-calendar.sh --year 2027    # 다른 연도
./batch/run-bwf-calendar.sh --dry-run      # DB 안 쓰고 JSON 출력
```

## 적재 전략

- 키: `tournament_id` UNIQUE
- 매 실행마다 동일 키에 대해 덮어쓰기 (upsert)
- 청크 단위 200개씩 분할 + dedupe (방어적)

## 실행 로그

```sql
select * from batch_logs where job = 'bwf_calendar'
order by started_at desc limit 5;
```

## 알려진 위험

- BWF가 토큰 발급 방식을 바꾸면 [bwf_rankings/fetcher.py](../bwf_rankings/fetcher.py)의 `extract_api_token`이 깨짐 → 두 job이 동시에 영향
- API 응답 필드 변경 시 parser가 `.get()` 기반이라 KeyError 안 나지만 결측은 가능. `raw` 컬럼에 원본 보존하므로 사후 재처리 가능
