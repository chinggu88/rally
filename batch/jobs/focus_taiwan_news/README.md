# focus_taiwan_news

[Focus Taiwan 스포츠 뉴스](https://focustaiwan.tw/sports)에서 제목이 `BADMINTON`으로
시작하는 기사만 수집해 `badminton_planet_news` 테이블에 `source='focustaiwan.tw'`로 upsert 한다.

## 동작

1. `badminton_planet_news` 테이블에서 `source='focustaiwan.tw'`인 기존 `url` 집합을 조회.
2. 목록 JSON API를 1페이지부터 순회.
   - `POST https://focustaiwan.tw/cna2019api/cna/FTNewsList/`
     (form data: `action=4&category=sports&pageidx=N&pagesize=10`)
   - 응답 `Items`: `PageUrl`(url), `HeadLine`(title), `CreateTime`(published_at, 대만시간 UTC+8),
     `Abstract`·`Image` 등은 `raw`에 보관.
3. 제목이 `BADMINTON`(대소문자 무시)으로 시작하는 기사만 선별.
   **필터 특성상 신규 0건 페이지도 계속 진행**하고, API `Items`가 비면(목록 끝) 종료.
4. `url` 충돌 기준으로 upsert.

## 환경변수

| 이름 | 기본값 | 설명 |
|---|---|---|
| `SUPABASE_URL` | — | 프로젝트 URL |
| `SUPABASE_SERVICE_KEY` | — | service_role 키 |
| `NEWS_MAX_PAGES` | `10` | 한 번에 훑을 최대 페이지 수 (API는 약 10~14페이지, 최근 3개월치 제공) |

## 실행

```bash
# 프로젝트 루트에서
source batch/.venv/bin/activate
PYTHONPATH=. python -m batch.jobs.focus_taiwan_news.main
```

## 스케줄

Docker + supercronic: [`batch/crontab`](../../crontab) — 매일 08:50, 17:50 KST.
