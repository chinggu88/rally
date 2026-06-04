# badminton_planet_news

[badmintonplanet.com 뉴스 목록](https://www.badmintonplanet.com/badminton-news.html)에서
아직 DB에 없는 신규 기사(url·제목 등)를 수집해 `badminton_planet_news` 테이블에 upsert 한다.

## 동작

1. `badminton_planet_news` 테이블의 기존 `url` 집합을 조회.
2. 최신 목록 페이지(`/page/N`)를 1페이지부터 순회하며 기사 카드를 파싱.
   - 카드: `h3.entry-title > a` (url·title), `.td-post-author-name`(author),
     `.td-post-category`(category), `time[datetime]`(published_at).
3. 기존에 없는 신규 기사만 모은다. **신규가 0건인 페이지를 만나면 따라잡은 것으로 보고 종료.**
4. `url` 충돌 기준으로 upsert.

## 환경변수

| 이름 | 기본값 | 설명 |
|---|---|---|
| `SUPABASE_URL` | — | 프로젝트 URL |
| `SUPABASE_SERVICE_KEY` | — | service_role 키 |
| `NEWS_MAX_PAGES` | `5` | 한 번에 훑을 최대 페이지 수. 최초 백필 시 크게 설정 |

## 실행

```bash
# 프로젝트 루트에서
source batch/.venv/bin/activate
PYTHONPATH=. python -m batch.jobs.badminton_planet_news.main

# 전체 백필 (예: 50페이지까지)
NEWS_MAX_PAGES=50 PYTHONPATH=. python -m batch.jobs.badminton_planet_news.main
```

## 스케줄

GitHub Actions: [`batch-badminton-planet-news.yml`](../../../.github/workflows/batch-badminton-planet-news.yml) — 매일 1회.
