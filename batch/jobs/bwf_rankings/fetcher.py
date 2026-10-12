import re
from contextlib import contextmanager
from typing import Any, Iterator

import requests
from playwright.sync_api import Page, sync_playwright
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from batch.shared.logger import get_logger

ENTRY_URL = "https://bwfbadminton.com/rankings/"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)
EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"
RANK_ID = 2  # BWF World Rankings

# Transient 5xx / read timeouts on the extranet API; same policy as bwf_matches.
RETRY_TOTAL = 3
RETRY_BACKOFF_FACTOR = 1.0
RETRY_STATUS_FORCELIST = (429, 500, 502, 503, 504)

# Page sizes to fall back through when a page keeps 500-ing. Each one divides
# the previous, so a failed page at size N maps onto exactly N/M pages at size M.
PAGE_SIZES = (1000, 100, 10, 1)

log = get_logger(__name__)


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
    """Legacy helper kept for other jobs that still rely on Bearer auth.

    The public rankings endpoints no longer require this token — see
    `get_latest_publication` / `fetch_all_pages` below, which hit the API
    directly. This function remains for callers (e.g. bwf_calendar, probes)
    that have not migrated.
    """
    page.goto(ENTRY_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_selector("#rankings_landing_container", timeout=30_000)
    html = page.content()
    m = re.search(r'token:\s*"([^"]+)"', html)
    if not m:
        raise RuntimeError("Could not extract API token from rankings page")
    return m.group(1)


def _api_session() -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "Accept": "application/json, text/plain, */*",
            "Origin": "https://bwfbadminton.com",
            "Referer": "https://bwfbadminton.com/",
            "User-Agent": USER_AGENT,
        }
    )
    retry = Retry(
        total=RETRY_TOTAL,
        backoff_factor=RETRY_BACKOFF_FACTOR,
        status_forcelist=RETRY_STATUS_FORCELIST,
        allowed_methods=frozenset(["GET"]),
        raise_on_status=False,
    )
    s.mount("https://", HTTPAdapter(max_retries=retry))
    return s


def get_latest_publication() -> dict[str, Any]:
    """Fetch the list of available ranking weeks; return the first (latest)."""
    s = _api_session()
    r = s.get(
        f"{EXTRANET_BASE}/api/vue-rankingweek",
        params={"rankId": RANK_ID},
        timeout=30,
    )
    r.raise_for_status()
    weeks = r.json()
    if not weeks:
        raise RuntimeError("vue-rankingweek returned empty list")
    return weeks[0]


def fetch_category_page(
    cat_id: int,
    publication_id: int,
    page_key: int,
    page: int,
    draw_count: int,
    session: requests.Session | None = None,
) -> dict[str, Any]:
    s = session or _api_session()
    params = {
        "rankId": RANK_ID,
        "catId": cat_id,
        "publicationId": publication_id,
        "doubles": "true" if cat_id >= 8 else "false",
        "searchKey": "",
        "pageKey": page_key,
        "page": page,
        "drawCount": draw_count,
    }
    r = s.get(
        f"{EXTRANET_BASE}/api/vue-rankingtable",
        params=params,
        timeout=60,
    )
    r.raise_for_status()
    return r.json()


def _fetch_page_rows(
    s: requests.Session,
    cat_id: int,
    publication_id: int,
    page_key: int,
    page: int,
    draw_count: int,
) -> tuple[list[dict[str, Any]], int | None]:
    """Return (rows, total) for one page.

    If the server keeps answering 5xx for this page (a single corrupt player row
    poisons every page size that contains it), re-fetch the same row range as
    smaller pages and skip only the row(s) that still fail on their own.
    """
    try:
        data = fetch_category_page(
            cat_id=cat_id,
            publication_id=publication_id,
            page_key=page_key,
            page=page,
            draw_count=draw_count,
            session=s,
        )
    except requests.HTTPError as e:
        status = e.response.status_code if e.response is not None else 0
        if status < 500:
            raise
        idx = PAGE_SIZES.index(page_key)
        if idx == len(PAGE_SIZES) - 1:
            log.warning(
                f"catId={cat_id} pub={publication_id}: skipping row offset "
                f"{page} (API returns {status} for it at every page size)"
            )
            return [], None
        smaller = PAGE_SIZES[idx + 1]
        factor = page_key // smaller
        log.warning(
            f"catId={cat_id} pub={publication_id}: pageKey={page_key} page={page} "
            f"returned {status}; re-fetching as pageKey={smaller}"
        )
        rows: list[dict[str, Any]] = []
        total: int | None = None
        for sub_page in range((page - 1) * factor + 1, page * factor + 1):
            sub_rows, sub_total = _fetch_page_rows(
                s, cat_id, publication_id, smaller, sub_page, draw_count
            )
            rows.extend(sub_rows)
            total = total if sub_total is None else sub_total
        return rows, total

    results = data.get("results") or {}
    return results.get("data") or [], results.get("total")


def fetch_all_pages(
    cat_id: int,
    publication_id: int,
    page_key: int = PAGE_SIZES[0],
) -> Iterator[dict[str, Any]]:
    """Yield every player row across all pages for the given category."""
    if page_key not in PAGE_SIZES:
        raise ValueError(f"page_key must be one of {PAGE_SIZES}, got {page_key}")
    s = _api_session()
    page_no = 1
    while True:
        rows, total = _fetch_page_rows(
            s, cat_id, publication_id, page_key, page_no, draw_count=page_no
        )
        for row in rows:
            yield row

        if not rows or total is None or page_no * page_key >= total:
            return
        page_no += 1
