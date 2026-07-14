# smash_net_news

[SMASH and NET. TV 새소식](https://www.smash-net.tv/topic/)의 **試合結果(경기 결과) 탭** 기사를
수집해 `badminton_planet_news` 테이블에 `source='smash-net.tv'`로 upsert 한다.

## 동작

1. `badminton_planet_news` 테이블에서 `source='smash-net.tv'`인 기존 `url` 집합을 조회.
2. 새소식 페이지를 1회 요청 — 한 페이지에 전체 연도(2008~) 기사가 모두 들어 있다 (페이지네이션 없음).
   - 구조: `div#tab0 > div.tab0-YYYY > ul.topics001-news > li > a`
     (`h3.date` `07月05日`, `p.msg` 제목. 연도는 부모 div 클래스에서 추출)
3. `NEWS_MIN_YEAR`(기본: 올해) 이후 연도의 試合結果 기사만 선별.
   - `published_at`: `YYYY-MM-DDT00:00:00+09:00` (일본시간, 시각 미제공이라 자정 고정)
4. `url` 충돌 기준으로 upsert.

## 환경변수

| 이름 | 기본값 | 설명 |
|---|---|---|
| `SUPABASE_URL` | — | 프로젝트 URL |
| `SUPABASE_SERVICE_KEY` | — | service_role 키 |
| `NEWS_MIN_YEAR` | 올해 | 이 연도부터 수집. 백필 시 낮게 설정 (예: 2024) |

## 실행

```bash
# 프로젝트 루트에서
source batch/.venv/bin/activate
PYTHONPATH=. python -m batch.jobs.smash_net_news.main

# 백필 (예: 2024년부터)
NEWS_MIN_YEAR=2024 PYTHONPATH=. python -m batch.jobs.smash_net_news.main
```

## 스케줄

Docker + supercronic: [`batch/crontab`](../../crontab) — 매일 08:55, 17:55 KST.
