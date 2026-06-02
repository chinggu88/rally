"""Map BWF data into bwf_tournaments + bwf_live_matches rows.

두 단계 파싱:
  1) vue-current-live JSON → 라이브 대회 메타 (parent bwf_tournaments row)
  2) results 페이지 HTML 카드 → 라이브 경기 (bwf_live_matches row, 매치당 1행)

라이브 경기 row는 매치 컬럼(team1_*, score, court_name, ...)이 모두 채워진다.
'대회 단위 1행' 더미는 더 이상 만들지 않는다 — 사용자 선택(경기 행으로 교체).
"""
from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any

# 기존 캘린더 파서와 동일한 카테고리 매핑 — 같은 의미를 유지하기 위해 복제.
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
_NAME_TO_CAT_ID = {
    "FINALS": 8,
    "SUPER_1000": 9,
    "SUPER_750": 10,
    "SUPER_500": 11,
    "SUPER_300": 12,
}
_SUFFIX_RE = re.compile(r"suffix_(finals|1000|750|500|300)")

# results 페이지 카드 텍스트 라인에서 이벤트/라운드/코트/시간 후처리용.
_EVENT_RE = re.compile(r"^(MS|WS|MD|WD|XD)$")
_ROUND_RE = re.compile(r"^(R\d+|QF|SF|F|FINAL|RR)$", re.IGNORECASE)
_COURT_RE = re.compile(r"^Court\s+(.+)$", re.IGNORECASE)
_DURATION_RE = re.compile(r"^\d{1,2}:\d{2}$")


# ---- vue-current-live → parent tournaments ---------------------------------


def parse_live_tournaments(
    payload: dict[str, Any],
    year: int,
) -> list[dict[str, Any]]:
    """Return parent bwf_tournaments rows (one per live tournament)."""
    out: list[dict[str, Any]] = []
    if not isinstance(payload, dict):
        return out
    for t in payload.get("results") or []:
        row = _parent_row(t, year)
        if row is not None:
            out.append(row)
    return out


def live_tournament_routing_info(payload: dict[str, Any]) -> list[dict[str, Any]]:
    """Return [{tournament_id, slug, name}, ...] for the results-page navigator.

    main.py는 이 목록을 받아 fetch_live_match_cards를 호출한다.
    """
    out: list[dict[str, Any]] = []
    if not isinstance(payload, dict):
        return out
    for t in payload.get("results") or []:
        tid = t.get("id")
        slug = _str(t.get("slug"))
        name = _str(t.get("name"))
        code = _str(t.get("code"))
        if isinstance(tid, int) and slug and name and code:
            out.append({"tournament_id": tid, "slug": slug, "name": name, "code": code})
    return out


def _parent_row(t: dict[str, Any], year: int) -> dict[str, Any] | None:
    tid = t.get("id")
    code = t.get("code")
    name = t.get("name")
    if not isinstance(tid, int) or not code or not name:
        return None

    tour_level = _resolve_tour_level(t)
    cat_id = _NAME_TO_CAT_ID.get(tour_level)

    return {
        "tournament_id": tid,
        "code": str(code),
        "name": str(name),
        "tour_level": tour_level,
        "category_id": cat_id,
        "start_date": _date_only(t.get("start_date")),
        "end_date": _date_only(t.get("end_date")),
        "date_label": _str(t.get("date")),
        "country": None,
        "location": _str(t.get("venue_name")),
        "prize_money_usd": _to_money(t.get("prize_money")),
        "detail_url": _str(t.get("tmtLink")),
        "flag_url": None,
        "logo_url": _str(t.get("tmtLogo")),
        "cat_logo_url": _str(t.get("catLogo")),
        "status": "live",
        "has_live_scores": True,
        "year": year,
        "raw": t,
    }


# ---- results-page cards → live matches -------------------------------------


def parse_live_match_cards(
    cards: list[dict[str, Any]],
    tournament: dict[str, Any],
) -> list[dict[str, Any]]:
    """Map each rendered card to a bwf_live_matches row (match-level).

    `tournament` is the dict from vue-current-live["results"][i] for routing.
    """
    rows: list[dict[str, Any]] = []
    tid = tournament.get("tournament_id") or tournament.get("id")
    code = tournament.get("code")
    name = tournament.get("name")
    slug = tournament.get("slug")
    if not isinstance(tid, int):
        return rows

    now = datetime.now(timezone.utc).isoformat()
    for c in cards:
        match_id = c.get("matchId")
        if not isinstance(match_id, int):
            continue
        event, round_name, court, duration_min = _extract_meta(c.get("lines") or [])
        team1, team2 = _split_teams(c.get("participants") or [])
        sets = c.get("sets") or []

        row = {
            "id": match_id,
            "match_code": None,                 # results 카드에 없음 — 후속 API 호출이 필요
            "tournament_id": tid,
            "tournament_code": str(code) if code else None,
            "tournament_status": "live",
            "draw_id": None,
            "draw_code": None,
            "event_name": event,
            "match_type": None,
            "round_name": round_name,
            "match_status": "L" if sets else None,    # 'L' = Live convention
            "match_status_value": "Live",
            "score_status": 0,
            "score_status_value": "Normal",
            "winner": None,                     # 아직 진행 중
            "team1_country": team1["country"] if team1 else None,
            "team2_country": team2["country"] if team2 else None,
            "team1_player_ids": team1["player_ids"] if team1 else None,
            "team2_player_ids": team2["player_ids"] if team2 else None,
            "team1_names": team1["names"] if team1 else None,
            "team2_names": team2["names"] if team2 else None,
            "team1_seed": team1["seed"] if team1 else None,
            "team2_seed": team2["seed"] if team2 else None,
            "score": sets or None,
            "match_time": None,
            "match_time_utc": None,
            "duration_min": duration_min,
            "court_name": court,
            "location_name": None,
            # 라이브 UI 핫패스 — 매치 row도 대회 컨텍스트를 들고 있도록 같이 채움.
            # 같은 대회의 카드 N개가 같은 값을 들고 있어 정규화는 깨지지만, 라이브
            # 카드 UI에서 JOIN을 피해 stream → 즉시 표시할 수 있는 이득이 크다.
            "slug": _str(slug),
            "name": _str(name),
            "start_date": None,
            "end_date": None,
            "date_label": None,
            "prize_money_usd": None,
            "detail_url": _str(c.get("href")),
            "logo_url": None,
            "header_image_url": None,
            "header_image_mobile_url": None,
            "cat_logo_url": None,
            "category_name": None,
            "tournament_category_id": None,
            "tournament_series_id": None,
            "is_etihad": None,
            "raw": c,
            "last_polled_at": now,
            "promoted_at": None,
        }
        rows.append(row)
    return rows


# ---- helpers ---------------------------------------------------------------


def _extract_meta(lines: list[str]) -> tuple[str | None, str | None, str | None, int | None]:
    """Find event, round, court name, duration(min) from card text lines.

    카드 텍스트 패턴 예: 'MATCH 1', 'FENG Y Z', 'HUANG D P', '(1)',
                      'J WONG', 'CHENG S Y', '21', '19',
                      'XD', 'R32', 'Court 1', '00:18'
    """
    event = round_name = court = None
    duration_min: int | None = None
    for line in lines:
        if event is None and _EVENT_RE.match(line):
            event = line
        elif round_name is None and _ROUND_RE.match(line):
            round_name = line.upper()
        elif court is None:
            m = _COURT_RE.match(line)
            if m:
                court = f"Court {m.group(1).strip()}"
        elif duration_min is None and _DURATION_RE.match(line):
            mm, ss = line.split(":")
            duration_min = int(mm) + (1 if int(ss) >= 30 else 0)
    return event, round_name, court, duration_min


def _split_teams(participants: list[dict[str, Any]]) -> tuple[dict | None, dict | None]:
    """participants[0] -> team1, participants[1] -> team2."""
    def _shape(p: dict[str, Any]) -> dict[str, Any]:
        players = p.get("players") or []
        ids: list[int] = []
        names: list[str] = []
        for pl in players:
            pid = _to_int(pl.get("id"))
            if pid is not None:
                ids.append(pid)
            nm = _str(pl.get("name"))
            if nm:
                names.append(nm)
        return {
            "country": _str(p.get("country")),
            "player_ids": ids or None,
            "names": names or None,
            "seed": _normalize_seed(p.get("seed")),
        }

    t1 = _shape(participants[0]) if len(participants) >= 1 else None
    t2 = _shape(participants[1]) if len(participants) >= 2 else None
    return t1, t2


def _normalize_seed(seed: Any) -> str | None:
    """'(1)' → '1', '' → None."""
    if seed is None:
        return None
    s = str(seed).strip()
    if not s:
        return None
    s = s.strip("()").strip()
    return s or None


def _resolve_tour_level(t: dict[str, Any]) -> str:
    cat = t.get("category_model") or {}
    name = cat.get("name") if isinstance(cat, dict) else None
    if isinstance(name, str):
        lvl = _NAME_TO_LEVEL.get(name.strip())
        if lvl:
            return lvl
    cat_logo = t.get("catLogo") or ""
    if isinstance(cat_logo, str):
        m = _SUFFIX_RE.search(cat_logo.lower())
        if m:
            lvl = _SUFFIX_TO_LEVEL.get(m.group(1))
            if lvl:
                return lvl
    return (name or "UNKNOWN").strip() or "UNKNOWN"


def _str(v: Any) -> str | None:
    if v is None:
        return None
    s = str(v).strip()
    return s or None


def _to_int(v: Any) -> int | None:
    if v is None or v == "":
        return None
    try:
        return int(str(v).strip())
    except (TypeError, ValueError):
        return None


def _to_money(v: Any) -> float | None:
    if v is None or v == "":
        return None
    try:
        return float(str(v).replace(",", "").replace("$", "").strip())
    except (TypeError, ValueError):
        return None


def _date_only(v: Any) -> str | None:
    if not v or not isinstance(v, str):
        return None
    head = v.split(" ", 1)[0]
    return head or None
