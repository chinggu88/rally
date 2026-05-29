import re
from contextlib import contextmanager
from typing import Any, Iterator

import requests
from playwright.sync_api import Page, sync_playwright
from supabase import Client

# Player profile data comes from the same extranet API the rankings job uses —
# NOT from the HTML player page (which is behind Cloudflare bot protection).
EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"
ENTRY_URL = "https://bwfbadminton.com/rankings/"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


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
    """Lift the Bearer token embedded in the rankings landing page.

    Mirrors batch/jobs/bwf_rankings/fetcher.extract_api_token. Only the rankings
    entry page is loaded via the browser; everything else uses plain HTTP, so
    Cloudflare never sees a headless browser hitting player pages.
    """
    page.goto(ENTRY_URL, wait_until="domcontentloaded", timeout=60_000)
    page.wait_for_selector("#rankings_landing_container", timeout=30_000)
    html = page.content()
    m = re.search(r'token:\s*"([^"]+)"', html)
    if not m:
        raise RuntimeError("Could not extract API token from rankings page")
    return m.group(1)


def api_session(token: str) -> requests.Session:
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


def fetch_player_summary(s: requests.Session, player_id: int) -> dict[str, Any]:
    r = s.post(
        f"{EXTRANET_BASE}/api/vue-player-summary",
        json={"drawCount": 1, "playerId": str(player_id), "isPara": False},
        timeout=30,
    )
    r.raise_for_status()
    data = r.json()
    return data.get("results") or {}


def fetch_player_bio(s: requests.Session, player_id: int) -> dict[str, Any]:
    """Supplementary bio endpoint (age, hand, prize_money, social).

    Returns {} on any error — the summary endpoint already carries the core
    fields, so bio is best-effort enrichment.
    """
    try:
        r = s.post(
            f"{EXTRANET_BASE}/api/vue-player-bio",
            json={"activeTab": 1, "playerId": str(player_id)},
            timeout=30,
        )
        r.raise_for_status()
        data = r.json()
        if isinstance(data, dict):
            return data.get("results") if isinstance(data.get("results"), dict) else data
    except Exception:
        pass
    return {}


def extract_player_id_from_url(detail_url: str) -> int | None:
    """`https://bwfbadminton.com/player/57945/` or `/player/57945/shi-yu-qi/` → 57945."""
    if not detail_url:
        return None
    m = re.search(r"/player/(\d+)", detail_url)
    return int(m.group(1)) if m else None


def collect_detail_urls(supabase: Client) -> list[tuple[int, str]]:
    """Return deduped `(player_id, detail_url)` pairs from bwf_rankings.

    Falls back to parsing player_id from the URL when bwf_rankings.player1_id/player2_id is NULL.
    Pages through 1000 rows at a time to bypass Supabase's default response cap.
    """
    seen: dict[int, str] = {}
    page_size = 1000
    offset = 0
    while True:
        res = (
            supabase.table("bwf_rankings")
            .select(
                "player1_id, player1_detail_url, player2_id, player2_detail_url"
            )
            .range(offset, offset + page_size - 1)
            .execute()
        )
        rows = res.data or []
        if not rows:
            break

        for row in rows:
            for pid_key, url_key in (
                ("player1_id", "player1_detail_url"),
                ("player2_id", "player2_detail_url"),
            ):
                url = row.get(url_key)
                if not url:
                    continue
                pid = row.get(pid_key) or extract_player_id_from_url(url)
                if pid and pid not in seen:
                    seen[pid] = url

        if len(rows) < page_size:
            break
        offset += page_size

    return sorted(seen.items())


def backfill_ranking_player_ids(supabase: Client) -> int | None:
    """Invoke the SQL helper that splits member_id into player1_id/player2_id.

    Returns the number of rows touched, or None if the RPC is unavailable.
    """
    try:
        res = supabase.rpc("bwf_backfill_ranking_player_ids").execute()
        return res.data if isinstance(res.data, int) else None
    except Exception:
        return None
