"""HTTP access to the BWF year calendar.

As of 2026, BWF moved this endpoint from POST+Bearer-token to plain GET with
no auth — only Referer/User-Agent are required. Mirrors the same pattern as
batch/jobs/bwf_matches/fetcher.py.
"""
from typing import Any

import requests

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)
EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"

# HSBC BWF World Tour calendar category ids (Finals + Super 1000/750/500/300,
# Super 100, and Grade 1 Team/Individual tournaments).
CATEGORY_IDS = [20, 21, 22, 23, 24, 25, 26, 27]


def _session() -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "Accept": "application/json, text/plain, */*",
            "Origin": "https://bwfworldtour.bwfbadminton.com",
            "Referer": "https://bwfworldtour.bwfbadminton.com/",
            "User-Agent": USER_AGENT,
        }
    )
    return s


def fetch_year_tournaments(year: int) -> dict[str, Any]:
    """Fetch the full year's tournaments for HSBC World Tour categories.

    Response shape: {"results": [...], "remaining": [...], "completed": [...]}
    where each is a list of monthly groups: {"month", "monthNo", "tournaments": [...]}.
    """
    params = [("year", year)] + [("category[]", c) for c in CATEGORY_IDS]
    r = _session().get(
        f"{EXTRANET_BASE}/api/vue-grouped-year-tournaments",
        params=params,
        timeout=60,
    )
    r.raise_for_status()
    return r.json()
