"""HTTP access to the BWF year calendar.

Same token-then-HTTP pattern as the other BWF jobs: a headless browser lifts the
Bearer token from the rankings landing page once, then the calendar API is called
directly. The calendar endpoint groups tournaments by month under
results/remaining/completed.
"""
from typing import Any

import requests

from batch.jobs.bwf_rankings.fetcher import (  # noqa: F401  (re-exported for probes)
    USER_AGENT,
    browser_page,
    extract_api_token,
)

EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"

# HSBC BWF World Tour calendar category ids (Finals + Super 1000/750/500/300,
# Super 100, and Grade 1 Team/Individual tournaments).
CATEGORY_IDS = [20, 21, 22, 23, 24, 25, 26, 27]


def _session(token: str) -> requests.Session:
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


def fetch_year_tournaments(token: str, year: int) -> dict[str, Any]:
    """Fetch the full year's tournaments for HSBC World Tour categories.

    Response shape: {"results": [...], "remaining": [...], "completed": [...]}
    where each is a list of monthly groups: {"month", "monthNo", "tournaments": [...]}.
    """
    r = _session(token).post(
        f"{EXTRANET_BASE}/api/vue-grouped-year-tournaments",
        json={"year": year, "category": CATEGORY_IDS},
        timeout=60,
    )
    r.raise_for_status()
    return r.json()
