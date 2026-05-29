"""Transform BWF grouped-year-tournaments JSON into bwf_tournaments rows."""
import re
from typing import Any

# Canonical tour levels for the well-known World Tour grades. Other categories
# (Super 100, Team, Individual) fall through and keep their raw category name.
_NAME_TO_LEVEL = {
    "HSBC BWF World Tour Finals": "FINALS",
    "HSBC BWF World Tour Super 1000": "SUPER_1000",
    "HSBC BWF World Tour Super 750": "SUPER_750",
    "HSBC BWF World Tour Super 500": "SUPER_500",
    "HSBC BWF World Tour Super 300": "SUPER_300",
}

_SUFFIX_TO_LEVEL = {
    "finals": "FINALS",
    "1000": "SUPER_1000",
    "750": "SUPER_750",
    "500": "SUPER_500",
    "300": "SUPER_300",
}

# category_id stored alongside the canonical levels (kept for the well-known
# grades; non-canonical levels store None).
_NAME_TO_CAT_ID = {
    "FINALS": 8,
    "SUPER_1000": 9,
    "SUPER_750": 10,
    "SUPER_500": 11,
    "SUPER_300": 12,
}

_SUFFIX_RE = re.compile(r"suffix_(finals|1000|750|500|300)_")


def transform_results(payload: dict[str, Any], year: int) -> list[dict[str, Any]]:
    """Flatten payload's monthly groups (results/remaining/completed) into rows."""
    rows: list[dict[str, Any]] = []
    seen: set[int] = set()
    for key in ("results", "remaining", "completed"):
        groups = payload.get(key)
        # The API now returns plain counts (int) for remaining/completed; only
        # `results` carries the monthly tournament groups. Skip non-list values.
        if not isinstance(groups, list):
            continue
        for month_group in groups:
            if not isinstance(month_group, dict):
                continue
            for t in month_group.get("tournaments") or []:
                if not isinstance(t, dict):
                    continue
                row = _transform_one(t, year=year)
                if row and row["tournament_id"] not in seen:
                    seen.add(row["tournament_id"])
                    rows.append(row)
    return rows


def _transform_one(t: dict[str, Any], year: int) -> dict[str, Any] | None:
    tournament_id = t.get("id")
    name = t.get("name")
    if tournament_id is None or not name:
        return None

    # Canonical level when recognised; otherwise the raw category name so the
    # tournament is still stored (Super 100, Team, Individual, ...).
    tour_level = _resolve_level(t) or _str(t.get("category")) or "UNKNOWN"
    category_id = _NAME_TO_CAT_ID.get(tour_level)

    return {
        "tournament_id": int(tournament_id),
        "code": t.get("code"),
        "name": name,
        "tour_level": tour_level,
        "category_id": category_id,
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
        "has_live_scores": bool(t.get("has_live_scores")),
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
        return value.get("label") or value.get("status")
    return str(value)


def _date_only(value: Any) -> str | None:
    """'2026-01-06 00:00:00' -> '2026-01-06'."""
    if not value or not isinstance(value, str):
        return None
    return value.split(" ", 1)[0] or None


def _parse_money(value: Any) -> float | None:
    """'1,450,000' or '$1,450,000' -> 1450000.0."""
    if value is None or value == "":
        return None
    text = str(value).replace(",", "").replace("$", "").strip()
    if not text:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
