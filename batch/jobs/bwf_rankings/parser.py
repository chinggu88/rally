import re
from typing import Any

# BWF detail page; the site auto-redirects to /player/{id}/{slug}/.
# Mirrors PLAYER_DETAIL_URL in batch/jobs/bwf_players/fetcher.py — duplicated
# intentionally so this module stays Playwright-free for tests/imports.
PLAYER_DETAIL_URL = "https://bwfbadminton.com/player/{player_id}/"

_TAG_RE = re.compile(r"<[^>]+>")


def transform_row(
    row: dict[str, Any], category: str, year: int, week: int
) -> dict[str, Any] | None:
    rank = row.get("rank")
    points = row.get("points")
    if rank is None or points is None:
        return None

    p1 = row.get("player1_model") or {}
    p2 = row.get("player2_model") or {}
    p1_id = p1.get("id") or row.get("player1_id")
    p2_id = p2.get("id") or row.get("player2_id")

    names = [_player_name(p) for p in (p1, p2) if p]
    names = [n for n in names if n]
    if not names:
        return None

    if p1_id and p2_id:
        member_id = f"{p1_id}-{p2_id}"
    elif p1_id:
        member_id = str(p1_id)
    else:
        return None

    country_code, country_name = _country(row, p1, p2)

    p1_detail_url = PLAYER_DETAIL_URL.format(player_id=p1_id) if p1_id else None
    p2_detail_url = PLAYER_DETAIL_URL.format(player_id=p2_id) if p2_id else None

    return {
        "category": category,
        "rank": int(rank),
        "member_id": member_id,
        "player_name": " / ".join(names),
        "country_code": country_code,
        "country_name": country_name,
        "tournaments": _to_int(row.get("tournaments")),
        "points": float(points),
        "ranking_year": year,
        "ranking_week": week,
        "player1_detail_url": p1_detail_url,
        "player2_detail_url": p2_detail_url,
        "rank_change": _to_int(row.get("rank_change")),
    }


def transform_rows(
    rows: list[dict[str, Any]], category: str, year: int, week: int
) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for row in rows:
        rec = transform_row(row, category, year, week)
        if rec is not None:
            out.append(rec)
    return out


def _player_name(player: dict[str, Any]) -> str:
    display = player.get("name_display")
    if display:
        return display.strip()
    bold = player.get("name_display_bold")
    if bold:
        # Strip HTML tags from "<span class=\"name-2\">KIM</span> <span class=\"name-1\">Won Ho</span>"
        text = _TAG_RE.sub("", bold)
        # Collapse whitespace.
        return " ".join(text.split())
    first = (player.get("first_name") or "").strip()
    last = (player.get("last_name") or "").strip()
    return f"{last} {first}".strip()


def _country(
    row: dict[str, Any], p1: dict[str, Any], p2: dict[str, Any]
) -> tuple[str | None, str | None]:
    candidates = [
        row.get("p1_country_model"),
        p1.get("country_model") if p1 else None,
        row.get("p2_country_model"),
        p2.get("country_model") if p2 else None,
    ]
    for c in candidates:
        if not isinstance(c, dict):
            continue
        if c.get("code_iso3"):
            return c["code_iso3"], c.get("name")
        if c.get("name"):
            return None, c["name"]
    fallback = row.get("p1_country") or (p1.get("country") if p1 else None)
    return (fallback or None), None


def _to_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None
