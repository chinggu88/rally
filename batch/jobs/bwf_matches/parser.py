"""Map BWF draw-data `matches` entries to `bwf_matches` rows."""
from datetime import datetime
from typing import Any

# Calendar live_status -> our 3-state lifecycle.
#   future / pre -> 대회전, live -> 대회중, post / completed -> 대회후
LIVE_STATUS_MAP = {
    "future": "pre",
    "pre": "pre",
    "live": "live",
    "post": "post",
    "completed": "post",
    "complete": "post",
}


def normalize_status(live_status: Any) -> str:
    """Collapse the calendar's live_status into 'pre' | 'live' | 'post'."""
    return LIVE_STATUS_MAP.get(str(live_status or "").lower(), "pre")


def parse_match(
    match: dict[str, Any],
    tournament: dict[str, Any],
    draw: dict[str, Any],
    tournament_status: str,
) -> dict[str, Any] | None:
    """Build one `bwf_matches` row, or None if the match has no stable id.

    `match`   — one element of vue-tournament-draw-data["matches"].
    `tournament` — the calendar tournament dict (for id/code).
    `draw`    — the vue-tournament-draws entry (for draw_id/event).
    `tournament_status` — pre|live|post snapshot for this crawl.
    """
    match_id = match.get("id")
    if not isinstance(match_id, int):
        return None

    team1 = match.get("team1") or {}
    team2 = match.get("team2") or {}

    row: dict[str, Any] = {
        "id": match_id,
        "match_code": _str(match.get("code")),
        "tournament_id": int(tournament.get("id")),
        "tournament_code": _str(match.get("tournamentCode")) or _str(tournament.get("code")),
        "tournament_status": tournament_status,
        "draw_id": _str(draw.get("value")),
        "draw_code": _str(match.get("drawCode")),
        "event_name": _str(match.get("eventName")) or _str(draw.get("text")),
        "match_type": _str(match.get("matchTypeValue")),
        "round_name": _str(match.get("roundName")),
        "match_status": _str(match.get("matchStatus")),
        "match_status_value": _str(match.get("matchStatusValue")),
        "score_status": _to_int(match.get("scoreStatus")),
        "score_status_value": _str(match.get("scoreStatusValue")),
        "winner": _to_int(match.get("winner")),
        "team1_country": _str(team1.get("countryCode")),
        "team2_country": _str(team2.get("countryCode")),
        "team1_player_ids": _player_ids(team1),
        "team2_player_ids": _player_ids(team2),
        "team1_names": _player_names(team1),
        "team2_names": _player_names(team2),
        "team1_seed": _str(match.get("team1seed")),
        "team2_seed": _str(match.get("team2seed")),
        "score": match.get("score") if isinstance(match.get("score"), list) else None,
        "match_time": _parse_dt(match.get("matchTime")),
        "match_time_utc": _parse_dt(match.get("matchTimeUtc"), utc=True),
        "duration_min": _to_int(match.get("duration")),
        "court_name": _str(match.get("courtName")),
        "location_name": _str(match.get("locationName")),
        "raw": match,
        "crawled_at": datetime.utcnow().isoformat() + "Z",
    }
    return row


def _player_ids(team: dict[str, Any]) -> list[int]:
    ids: list[int] = []
    for p in team.get("players") or []:
        pid = _to_int(p.get("id"))
        if pid is not None:
            ids.append(pid)
    return ids


def _player_names(team: dict[str, Any]) -> list[str]:
    names: list[str] = []
    for p in team.get("players") or []:
        name = _str(p.get("nameDisplay"))
        if name:
            names.append(name)
    return names


def _parse_dt(value: Any, utc: bool = False) -> str | None:
    """Parse 'YYYY-MM-DD HH:MM:SS' to ISO; append 'Z' for the UTC field."""
    if not value:
        return None
    text = str(value).strip()
    if not text or text.startswith("0000"):
        return None
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
        try:
            dt = datetime.strptime(text, fmt)
            return dt.isoformat() + ("Z" if utc else "")
        except ValueError:
            continue
    return None


def _to_int(value: Any) -> int | None:
    if value is None or value == "":
        return None
    try:
        return int(str(value).strip())
    except (ValueError, TypeError):
        return None


def _str(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None
