"""HTTP access to BWF tournament-detail / match data.

All match data comes from the extranet API the bwfworldtour SPA calls — NOT from
the Cloudflare-protected HTML page. A headless browser is used only once to lift
the Bearer token from the rankings landing page; every match request is plain
HTTP after that (same approach as bwf_rankings / bwf_players).

Endpoint chain per tournament:
  POST /api/vue-grouped-year-tournaments  -> calendar (tournament id + live_status)
  POST /api/vue-tournament-draws          -> disciplines for one tournament (drawId per event)
  POST /api/vue-tournament-draw-data      -> {"matches": [...]} for one draw
"""
from typing import Any, Iterator

import requests

# Reuse the token-extraction + browser helpers proven by the rankings job.
from batch.jobs.bwf_rankings.fetcher import (  # noqa: F401  (re-exported for probes)
    USER_AGENT,
    browser_page,
    extract_api_token,
)

EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"

# HSBC BWF World Tour category ids (Finals + Super 1000/750/500/300 and below),
# matching the existing calendar job. The calendar API splits these into
# results/remaining/completed monthly groups.
CATEGORY_IDS = [20, 21, 22, 23, 24, 25, 26, 27]


def api_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json, text/plain, */*",
            "Content-Type": "application/json;charset=UTF-8",
            # The draw-data endpoint is called by the bwfworldtour SPA, so mirror
            # its Origin/Referer.
            "Origin": "https://bwfworldtour.bwfbadminton.com",
            "Referer": "https://bwfworldtour.bwfbadminton.com/",
            "User-Agent": USER_AGENT,
        }
    )
    return s


def _flatten_groups(groups: Any) -> Iterator[dict[str, Any]]:
    """Yield tournament dicts out of the calendar's monthly-group lists."""
    if not isinstance(groups, list):
        return
    for group in groups:
        if not isinstance(group, dict):
            continue
        for t in group.get("tournaments") or []:
            if isinstance(t, dict):
                yield t


def fetch_year_calendar(s: requests.Session, year: int) -> list[dict[str, Any]]:
    """Return deduped tournaments for the year, each carrying its live_status.

    The calendar API nests tournaments under results/remaining/completed monthly
    groups; we flatten and dedupe by tournament id (last write wins). Each row
    keeps `id` and `live_status` ('future'|'pre'|'live'|'post'), which drives the
    대회전/대회중/대회후 classification downstream.
    """
    r = s.post(
        f"{EXTRANET_BASE}/api/vue-grouped-year-tournaments",
        json={"year": year, "category": CATEGORY_IDS},
        timeout=60,
    )
    r.raise_for_status()
    data = r.json()

    deduped: dict[int, dict[str, Any]] = {}
    for key in ("results", "remaining", "completed"):
        for t in _flatten_groups(data.get(key)):
            tid = t.get("id")
            if isinstance(tid, int):
                deduped[tid] = t
    return list(deduped.values())


def fetch_tournament_draws(s: requests.Session, tmt_id: int) -> list[dict[str, Any]]:
    """Return the discipline draws for a tournament.

    Each draw carries `value` (the drawId needed by draw-data), `text` (MS/WS/...),
    and `slug`. Returns [] when the draw isn't published yet (future tournaments).
    """
    r = s.post(
        f"{EXTRANET_BASE}/api/vue-tournament-draws",
        json={"tmtTab": "draw", "tmtId": tmt_id},
        timeout=30,
    )
    r.raise_for_status()
    results = r.json().get("results")
    return results if isinstance(results, list) else []


def fetch_draw_matches(
    s: requests.Session, tmt_id: int, draw_id: str
) -> list[dict[str, Any]]:
    """Return the `matches` array for one draw of one tournament.

    `draw_id` is the `value` from fetch_tournament_draws (per-tournament, not
    globally stable). Pre-tournament draws return matches with
    matchStatusValue == 'none' (no result yet).
    """
    r = s.post(
        f"{EXTRANET_BASE}/api/vue-tournament-draw-data",
        json={"tmtTab": "draw", "tmtId": tmt_id, "drawId": str(draw_id)},
        timeout=30,
    )
    r.raise_for_status()
    matches = r.json().get("matches")
    return matches if isinstance(matches, list) else []
