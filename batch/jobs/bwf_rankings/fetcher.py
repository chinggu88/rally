import re
from contextlib import contextmanager
from typing import Any, Iterator

import requests
from playwright.sync_api import Page, sync_playwright
from playwright_stealth import Stealth

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
    stealth = Stealth(init_scripts_only=True)
    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
            ],
        )
        context = browser.new_context(
            user_agent=USER_AGENT,
            viewport={"width": 1440, "height": 900},
            locale="en-US",
            extra_http_headers={
                "Accept-Language": "en-US,en;q=0.9",
            },
        )
        stealth.apply_stealth_sync(context)
        page = context.new_page()
        try:
            yield page
        finally:
            context.close()
            browser.close()


def extract_api_token(page: Page, attempts: int = 3) -> str:
    last_error: Exception | None = None
    for attempt in range(1, attempts + 1):
        try:
            # "commit" returns as soon as navigation is committed — avoids hangs
            # while Cloudflare's challenge scripts keep the network busy.
            page.goto(ENTRY_URL, wait_until="commit", timeout=90_000)
            page.wait_for_selector(
                "#rankings_landing_container", timeout=60_000, state="attached"
            )
            html = page.content()
            m = re.search(r'token:\s*"([^"]+)"', html)
            if not m:
                raise RuntimeError("Could not extract API token from rankings page")
            return m.group(1)
        except Exception as e:
            last_error = e
            if attempt == attempts:
                break
            page.wait_for_timeout(3_000 * attempt)
    title = ""
    url = ""
    snippet = ""
    try:
        title = page.title()
        url = page.url
        snippet = page.content()[:1500]
    except Exception:
        pass
    raise RuntimeError(
        f"Failed to load rankings page after {attempts} attempts. "
        f"url={url!r} title={title!r}\n"
        f"last error: {type(last_error).__name__}: {last_error}\n"
        f"--- first 1500 chars of HTML ---\n{snippet}"
    )


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
