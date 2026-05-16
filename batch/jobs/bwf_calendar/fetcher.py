from typing import Any

import requests

# Reuse the proven Cloudflare-aware browser + token extractor from bwf_rankings.
from batch.jobs.bwf_rankings.fetcher import (
    USER_AGENT,
    browser_page,
    extract_api_token,
)

EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"

# Category IDs sent in the API body. These are the same values the calendar
# page itself uses on first load and they return the 5 HSBC World Tour
# tiers we want — plus some adjacent categories (BWF Tour Super 100,
# Grade 1) which we filter out in the parser by tour-level label.
# Note: these are *group* IDs, not the per-tier IDs from
# /api/vue-tournament-categories (those map to a different filter axis).
CATEGORY_IDS: list[int] = [20, 21, 22, 23, 24, 25, 26, 27]

__all__ = [
    "browser_page",
    "extract_api_token",
    "CATEGORY_IDS",
    "fetch_year_tournaments",
]


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
