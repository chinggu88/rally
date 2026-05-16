import re
from typing import Any

# Map the API's category *name* string and the cat_logo "suffix_<N>" hint
# to our enum value. The /api/vue-tournament-categories endpoint confirms
# the underlying category ids (8..12), but the per-tournament payload only
# exposes the human label, so we match on label + logo as defence-in-depth.
_NAME_TO_LEVEL: dict[str, str] = {
    "HSBC BWF World Tour Finals": "FINALS",
    "HSBC BWF World Tour Super 1000": "SUPER_1000",
    "HSBC BWF World Tour Super 750": "SUPER_750",
    "HSBC BWF World Tour Super 500": "SUPER_500",
    "HSBC BWF World Tour Super 300": "SUPER_300",
}

_SUFFIX_TO_LEVEL: dict[str, str] = {
    "finals": "FINALS",
    "1000": "SUPER_1000",
    "750": "SUPER_750",
    "500": "SUPER_500",
    "300": "SUPER_300",
}

_NAME_TO_CAT_ID: dict[str, int] = {
    "FINALS": 8,
    "SUPER_1000": 9,
    "SUPER_750": 10,
    "SUPER_500": 11,
    "SUPER_300": 12,
}

_SUFFIX_RE = re.compile(r"suffix_(finals|1000|750|500|300)_", re.IGNORECASE)


def transform_results(payload: dict[str, Any], year: int) -> list[dict[str, Any]]:
    """Flatten payload['results'] (monthly groups) into a list of DB rows."""
    rows: list[dict[str, Any]] = []
    for month_group in payload.get("results") or []:
        for t in month_group.get("tournaments") or []:
            row = _transform_one(t, year=year)
            if row is not None:
                rows.append(row)
    return rows


def _transform_one(t: dict[str, Any], year: int) -> dict[str, Any] | None:
    tournament_id = t.get("id")
    name = t.get("name")
    if tournament_id is None or not name:
        return None

    tour_level = _resolve_level(t)
    if tour_level is None:
        # Defensive: skip anything that isn't one of our 5 HSBC categories.
        return None

    return {
        "tournament_id": int(tournament_id),
        "code": t.get("code"),
        "name": name,
        "tour_level": tour_level,
        "category_id": _NAME_TO_CAT_ID[tour_level],
        "start_date": _date_only(t.get("start_date")),
        "end_date": _date_only(t.get("end_date")),
        "date_label": t.get("date"),
        "country": t.get("country"),
        "location": t.get("location"),
        "prize_money_usd": _parse_money(t.get("prize_money")),
        "detail_url": t.get("url"),
        "flag_url": t.get("flag_url"),
        "logo_url": t.get("logo"),
        "cat_logo_url": t.get("cat_logo"),
        "status": _stringify_status(t.get("status")),
        "has_live_scores": bool(t.get("has_live_scores"))
        if t.get("has_live_scores") is not None
        else None,
        "year": year,
        "raw": t,
    }


def _resolve_level(t: dict[str, Any]) -> str | None:
    name = t.get("category")
    if isinstance(name, str):
        level = _NAME_TO_LEVEL.get(name.strip())
        if level:
            return level
    cat_logo = t.get("cat_logo")
    if isinstance(cat_logo, str):
        m = _SUFFIX_RE.search(cat_logo)
        if m:
            return _SUFFIX_TO_LEVEL.get(m.group(1).lower())
    return None


def _stringify_status(value: Any) -> str | None:
    if value is None or value == "":
        return None
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        # API returns {"status": "0", "label": "..."} — keep the human label.
        return value.get("label") or value.get("status")
    return str(value)


def _date_only(value: Any) -> str | None:
    if not value or not isinstance(value, str):
        return None
    return value.split(" ", 1)[0] or None


def _parse_money(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return float(value)
    s = str(value).replace(",", "").replace("$", "").strip()
    if not s:
        return None
    try:
        return float(s)
    except ValueError:
        return None
