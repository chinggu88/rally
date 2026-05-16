import re
from contextlib import contextmanager
from typing import Any, Iterator

import requests
from playwright.sync_api import Page, sync_playwright

ENTRY_URL = "https://bwfbadminton.com/rankings/"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)
EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"
RANK_ID = 2  # BWF World Rankings


@contextmanager
def browser_page() -> Iterator[Page]:
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent=USER_AGENT,
            viewport={"width": 1440, "height": 900},
            locale="en-US",
        )
        page = context.new_page()
        try:
            yield page
        finally:
            context.close()
            browser.close()


def extract_api_token(page: Page) -> str:
    page.goto(ENTRY_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_selector("#rankings_landing_container", timeout=30_000)
    html = page.content()
    m = re.search(r'token:\s*"([^"]+)"', html)
    if not m:
        raise RuntimeError("Could not extract API token from rankings page")
    return m.group(1)


def _api_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json, text/plain, */*",
            "Content-Type": "application/json;charset=UTF-8",
            "Origin": "https://bwfbadminton.com",
            "Referer": "https://bwfbadminton.com/",
            "User-Agent": USER_AGENT,
        }
    )
    return s


def get_latest_publication(token: str) -> dict[str, Any]:
    """Fetch the list of available ranking weeks; return the first (latest)."""
    s = _api_session(token)
    r = s.post(
        f"{EXTRANET_BASE}/api/vue-rankingweek",
        json={"rankId": RANK_ID},
        timeout=30,
    )
    r.raise_for_status()
    weeks = r.json()
    if not weeks:
        raise RuntimeError("vue-rankingweek returned empty list")
    return weeks[0]


def fetch_category_page(
    token: str,
    cat_id: int,
    publication_id: int,
    page_key: str,
    page: int,
    draw_count: int,
) -> dict[str, Any]:
    s = _api_session(token)
    payload = {
        "rankId": RANK_ID,
        "catId": cat_id,
        "publicationId": publication_id,
        "doubles": cat_id >= 8,
        "searchKey": "",
        "pageKey": page_key,
        "page": page,
        "drawCount": draw_count,
    }
    r = s.post(
        f"{EXTRANET_BASE}/api/vue-rankingtable",
        json=payload,
        timeout=60,
    )
    r.raise_for_status()
    return r.json()


def fetch_all_pages(
    token: str,
    cat_id: int,
    publication_id: int,
    page_key: str = "1000",
) -> Iterator[dict[str, Any]]:
    """Yield every player row across all pages for the given category."""
    draw = 1
    page_no = 1
    while True:
        data = fetch_category_page(
            token,
            cat_id=cat_id,
            publication_id=publication_id,
            page_key=page_key,
            page=page_no,
            draw_count=draw,
        )
        results = data.get("results") or {}
        rows = results.get("data") or []
        for row in rows:
            yield row

        last_page = results.get("last_page") or 1
        if page_no >= last_page or not rows:
            return
        page_no += 1
        draw += 1
