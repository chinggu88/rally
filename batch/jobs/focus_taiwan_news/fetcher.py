from typing import Any

import requests

# focustaiwan.tw 목록 페이지의 "More stories" 버튼이 호출하는 JSON API.
API_URL = "https://focustaiwan.tw/cna2019api/cna/FTNewsList/"
CATEGORY_SLUG = "sports"
PAGE_SIZE = 10
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


def fetch_page(page: int, timeout: int = 30) -> dict[str, Any]:
    """주어진 목록 페이지의 JSON 응답을 반환한다."""
    r = requests.post(
        API_URL,
        headers={"User-Agent": USER_AGENT},
        data={
            "action": "4",
            "category": CATEGORY_SLUG,
            "pageidx": page,
            "pagesize": str(PAGE_SIZE),
        },
        timeout=timeout,
    )
    r.raise_for_status()
    return r.json()
