"""HTTP access to BWF tournament-detail / match data.

All match data comes from the extranet API the bwfworldtour SPA calls — NOT from
the Cloudflare-protected HTML page. As of 2026, BWF moved these endpoints from
POST+Bearer-token to plain GET with no auth — only Referer/User-Agent are
required. The legacy `extract_api_token` browser dance is no longer needed for
this job.

Endpoint chain per tournament:
  GET /api/vue-grouped-year-tournaments  -> calendar (tournament id + live_status)
  GET /api/vue-tournament-draws          -> disciplines for one tournament (drawId per event)
  GET /api/vue-tournament-draw-data      -> {"matches": [...]} for one draw
"""
from typing import Any, Iterator

import requests

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)
EXTRANET_BASE = "https://extranet-lv.bwfbadminton.com"

# HSBC BWF World Tour category ids (Finals + Super 1000/750/500/300 and below),
# matching the existing calendar job. The calendar API splits these into
# results/remaining/completed monthly groups.
CATEGORY_IDS = [20, 21, 22, 23, 24, 25, 26, 27]


def api_session() -> requests.Session:
    """Session with just the headers the BWF SPA sends. No auth needed."""
    s = requests.Session()
    s.headers.update(
        {
            "Accept": "application/json, text/plain, */*",
            # Mirror the bwfworldtour SPA so the API doesn't drop us.
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
    # requests serializes list params as repeated `category[]=20&category[]=21...`
    # which is the form the BWF API expects.
    params = [("year", year)] + [("category[]", c) for c in CATEGORY_IDS]
    r = s.get(
        f"{EXTRANET_BASE}/api/vue-grouped-year-tournaments",
        params=params,
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
    r = s.get(
        f"{EXTRANET_BASE}/api/vue-tournament-draws",
        params={"tmtTab": "draw", "tmtId": tmt_id},
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

    The 2026 response shape carries two views of the same data — a `results`
    dict keyed by bracket slot ("0-0", "0-1"...) and a flat `matches` array.
    The flat array preserves the original `match.id` (stable BWF id) that the
    bwf_matches PK depends on, so we read from there.
    """
    r = s.get(
        f"{EXTRANET_BASE}/api/vue-tournament-draw-data",
        params={"tmtTab": "draw", "tmtId": tmt_id, "drawId": str(draw_id)},
        timeout=30,
    )
    r.raise_for_status()
    matches = r.json().get("matches")
    return matches if isinstance(matches, list) else []
