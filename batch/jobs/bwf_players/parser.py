import re
from datetime import datetime
from typing import Any

INT_RE = re.compile(r"-?\d+")

# BWF gender_id → schema gender
GENDER_MAP = {1: "M", 2: "F"}

# bio_model.plays code → human label
PLAYS_MAP = {"1": "Singles", "2": "Doubles", "3": "Both"}

# bio hand code → handedness
HAND_MAP = {"R": "right", "L": "left", "A": "ambidextrous"}

SOCIAL_FIELDS = ("instagram", "twitter", "facebook", "youtube", "tiktok", "weibo", "website")


def parse_player(
    summary: dict[str, Any], bio: dict[str, Any], player_id: int, detail_url: str
) -> dict[str, Any]:
    """Map BWF vue-player-summary (+ vue-player-bio) JSON to a `bwf_players` row.

    `summary` is the `results` object from /api/vue-player-summary.
    `bio` is the (best-effort) /api/vue-player-bio body.
    Every enrichment field is nullable; `id`, `name_display`, `detail_url` always set.
    """
    bio_model = summary.get("bio_model") or {}
    country_model = summary.get("country_model") or {}

    name_display = _clean(summary.get("name_display")) or f"Player {player_id}"

    country_code = (
        country_model.get("code_iso3") or summary.get("country") or summary.get("nationality")
    )
    country_name = country_model.get("name")

    height_cm = _parse_height_cm(bio_model.get("height") or bio.get("height"))
    handedness = _normalize_hand(bio.get("hand"))
    plays = PLAYS_MAP.get(str(bio_model.get("plays"))) if bio_model.get("plays") else None

    row: dict[str, Any] = {
        "id": int(summary.get("id") or player_id),
        "name_display": name_display,
        "first_name": _clean(summary.get("first_name")),
        "last_name": _clean(summary.get("last_name")),
        "gender": GENDER_MAP.get(summary.get("gender_id")),
        "country_code": _clean(country_code),
        "country_name": _clean(country_name),
        "birthday": _parse_birthday(summary.get("date_of_birth") or bio_model.get("dob")),
        "height_cm": height_cm,
        "handedness": handedness,
        "photo_url": _extract_photo_url(summary),
        "bio": _clean(bio_model.get("bwf_bio")),
        "coach": _clean(bio_model.get("coach")),
        "birthplace": _clean(bio_model.get("pob")),
        "plays": plays,
        "career_titles": _to_int(summary.get("career_titles")),
        "career_wins": _to_int(summary.get("career_wins")),
        "career_losses": _to_int(summary.get("career_losses")),
        "social_links": _extract_social_links(bio_model, bio),
        "detail_url": detail_url,
        "raw": {
            "summary": summary,
            "bio": bio,
        },
        "detail_fetched_at": datetime.utcnow().isoformat() + "Z",
    }
    return row


def _extract_photo_url(summary: dict[str, Any]) -> str | None:
    avatar = summary.get("avatar") or {}
    for key in ("url_cloudinary", "url_original", "url_large_image", "url_medium_image"):
        url = avatar.get(key)
        if url:
            return url
    return _clean(summary.get("avatar_url"))


def _extract_social_links(bio_model: dict[str, Any], bio: dict[str, Any]) -> dict[str, str]:
    links: dict[str, str] = {}
    for field in SOCIAL_FIELDS:
        value = bio_model.get(field)
        if isinstance(value, str) and value.strip():
            links[field] = value.strip()
    nested = bio.get("social") if isinstance(bio.get("social"), dict) else {}
    for field, value in nested.items():
        if isinstance(value, str) and value.strip() and field not in links:
            links[field] = value.strip()
    return links


def _parse_birthday(value: Any) -> str | None:
    if not value:
        return None
    text = str(value).strip()
    if not text or text.startswith("0000"):
        return None
    # API form: "1996-02-28 00:00:00"
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d", "%Y/%m/%d"):
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(text.replace("Z", "+00:00")).date().isoformat()
    except ValueError:
        return None


def _parse_height_cm(value: Any) -> int | None:
    if value is None:
        return None
    text = str(value).strip()
    m = re.search(r"\d{2,3}", text)
    if not m:
        return None
    cm = int(m.group(0))
    return cm if 100 <= cm <= 250 else None


def _normalize_hand(value: Any) -> str | None:
    if not value:
        return None
    code = str(value).strip().upper()[:1]
    return HAND_MAP.get(code)


def _to_int(value: Any) -> int | None:
    if value is None:
        return None
    m = INT_RE.search(str(value))
    if not m:
        return None
    try:
        return int(m.group(0))
    except ValueError:
        return None


def _clean(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
