# Test Fixtures

파서 단위 테스트용 샘플 HTML 저장 위치.

## 채우는 방법

첫 로컬 실행 후 `fetcher.fetch_rankings_html()`로 받은 HTML을 종목별 1개씩 저장:

```python
# batch/scripts/save_fixture.py 같은 일회용 스크립트로
from batch.jobs.bwf_rankings.fetcher import browser_page, detect_latest_week, fetch_rankings_html

with browser_page() as page:
    year, week = detect_latest_week(page)
    html = fetch_rankings_html(page, 6, "men-s-singles", year, week, rows=50)
    open("batch/tests/fixtures/bwf_ms_sample.html", "w").write(html)
```

저장 후 `test_bwf_parser.py`의 SKIP 가드 제거.
