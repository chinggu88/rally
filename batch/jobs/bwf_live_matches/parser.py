"""Map vue-live-matches JSON → bwf_live_matches rows (match per row).

새 흐름 (2026-06):
  부모 토너먼트는 bwf_tournaments에서 start_date ≤ today ≤ end_date 필터로
  직접 추출한다 (vue-current-live 캡처 단계 제거). 부모 row를 upsert하지 않으므로
  이 파서는 매치 단위 변환만 담당한다.

응답 스키마 (vue-live-matches):
  {
    "results": [
      {
        "live_detail": {
          "id", "match_id" (str = match_detail.code),
          "match_state" ('P'=In Progress 등), "match_state_name",
          "court_code", "court_name", "duration" (분),
          "event" ('MS'|'WS'|'MD'|'WD'|'XD'), "round" ('R32'|'QF'|...),
          "service_player" (1..4),
          "team{1,2}_g{1,2,3}_score"
        },
        "match_detail": {
          "id" (= bwf_matches.id 와 동일 체계 — 사용자 검증 완료),
          "tournament_id", "code",
          "team{1,2}_player{1,2}_id", "t{1,2}p{1,2}_country",
          "t{1,2}p{1,2}_player_model": { name_display, slug, playerLink, ... }
        }
      }
    ]
  }
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

# match_state 코드 → 라이브 여부 판정용. SPA 응답에서 본 값은 'P'(In Progress).
# 다른 값('U' upcoming, 'F' finished 등)이 섞여 들어오면 라이브로 보지 않는다.
_LIVE_STATES = {"P"}


def parse_live_matches(
    payload: dict[str, Any],
    tournament: dict[str, Any],
) -> list[dict[str, Any]]:
    """vue-live-matches 응답 + 부모 토너먼트 메타 → bwf_live_matches row 리스트.

    `tournament`는 bwf_tournaments에서 가져온 한 행. 라이브 카드 UI가 JOIN 없이
    바로 표시할 수 있도록 매치 row에도 대회 컨텍스트를 함께 박는다.
    """
    rows: list[dict[str, Any]] = []
    if not isinstance(payload, dict):
        return rows
    results = payload.get("results")
    if not isinstance(results, list):
        return rows

    tid = tournament.get("tournament_id")
    if not isinstance(tid, int):
        return rows

    now = datetime.now(timezone.utc).isoformat()
    for entry in results:
        if not isinstance(entry, dict):
            continue
        ld = entry.get("live_detail") or {}
        md = entry.get("match_detail") or {}
        if not isinstance(ld, dict) or not isinstance(md, dict):
            continue
        if str(ld.get("match_state") or "") not in _LIVE_STATES:
            # 진행 중이 아닌 항목은 라이브로 취급하지 않음 (mark_ended가 청소).
            continue
        row = _match_row(ld, md, tournament, now)
        if row is not None:
            rows.append(row)
    return rows


# ---- internal --------------------------------------------------------------


def _match_row(
    ld: dict[str, Any],
    md: dict[str, Any],
    tournament: dict[str, Any],
    now_iso: str,
) -> dict[str, Any] | None:
    match_id = _to_int(md.get("id"))
    if match_id is None:
        return None

    tid = _to_int(md.get("tournament_id")) or tournament.get("tournament_id")
    code = _str(md.get("code"))                       # 대회 내 매치 번호 ("203")

    team1_ids = _player_ids(md, "team1")
    team2_ids = _player_ids(md, "team2")
    team1_names = _player_names(md, "team1")
    team2_names = _player_names(md, "team2")
    team1_country = _team_country(md, "team1")
    team2_country = _team_country(md, "team2")

    score = _score_sets(ld)

    return {
        "id": match_id,
        # vue-live-matches는 BWF의 GUID(match_code)를 노출하지 않는다.
        # upserter._hydrate_match_codes가 (tid, event, 양 팀 선수 ID set) 키로 채운다.
        "match_code": None,
        "tournament_id": tid,
        "tournament_code": _str(tournament.get("code")),
        "tournament_status": "live",
        "draw_id": None,
        "draw_code": code,                            # 대회 내 매치 번호
        "event_name": _str(ld.get("event")),
        "match_type": None,
        "round_name": _str(ld.get("round")),
        "match_status": ld.get("match_state") or None,
        "match_status_value": _str(ld.get("match_state_name")),
        "score_status": 0,
        "score_status_value": "Normal",
        "winner": None,
        "team1_country": team1_country,
        "team2_country": team2_country,
        "team1_player_ids": team1_ids or None,
        "team2_player_ids": team2_ids or None,
        "team1_names": team1_names or None,
        "team2_names": team2_names or None,
        "team1_seed": None,                           # vue-live-matches에 시드 없음
        "team2_seed": None,
        "score": score or None,
        "match_time": None,
        "match_time_utc": None,
        "duration_min": _to_int(ld.get("duration")),
        "court_name": _str(ld.get("court_name")),
        "location_name": _str(tournament.get("location")),
        # 라이브 UI 핫패스 — JOIN 없이 stream으로 즉시 표시할 수 있도록 대회 메타 동봉.
        "slug": _slug_from_url(tournament.get("detail_url")),
        "name": _str(tournament.get("name")),
        "start_date": _date_only(tournament.get("start_date")),
        "end_date": _date_only(tournament.get("end_date")),
        "date_label": _str(tournament.get("date_label")),
        "prize_money_usd": tournament.get("prize_money_usd"),
        "detail_url": _str(tournament.get("detail_url")),
        "logo_url": _str(tournament.get("logo_url")),
        "header_image_url": None,
        "header_image_mobile_url": None,
        "cat_logo_url": _str(tournament.get("cat_logo_url")),
        "category_name": None,
        "tournament_category_id": tournament.get("category_id"),
        "tournament_series_id": None,
        "is_etihad": None,
        "raw": {"live_detail": ld, "match_detail": md},
        "last_polled_at": now_iso,
        "promoted_at": None,
    }


def _player_ids(md: dict[str, Any], team: str) -> list[int]:
    ids: list[int] = []
    for slot in ("player1", "player2"):
        pid = _to_int(md.get(f"{team}_{slot}_id"))
        if pid is not None:
            ids.append(pid)
    return ids


def _player_names(md: dict[str, Any], team: str) -> list[str]:
    """t{N}p{1,2}_player_model.name_display 우선, 없으면 fullName."""
    prefix = "t1" if team == "team1" else "t2"
    out: list[str] = []
    for slot in ("p1", "p2"):
        model = md.get(f"{prefix}{slot}_player_model")
        if not isinstance(model, dict):
            continue
        name = (
            _str(model.get("name_display"))
            or _str(model.get("fullName"))
            or _str(model.get("name_short1"))
        )
        if name:
            out.append(name)
    return out


def _team_country(md: dict[str, Any], team: str) -> str | None:
    """팀 국가 — 단식은 한 선수의 국가, 복식은 두 선수 국가가 같으면 그 국가.

    응답에 t1p1_country/t1p2_country가 분리돼 있다. 다국적 복식이면 None.
    """
    prefix = "t1" if team == "team1" else "t2"
    c1 = _str(md.get(f"{prefix}p1_country"))
    c2 = _str(md.get(f"{prefix}p2_country"))
    if c1 and c2:
        return c1 if c1 == c2 else None
    return c1 or c2


def _score_sets(ld: dict[str, Any]) -> list[dict[str, Any]]:
    """live_detail의 게임별 점수 컬럼을 sets 리스트로 정규화.

    [{"set": 1, "home": 13, "away": 21}, ...] — 기존 results-page 파서와 같은 모양.
    home=team1, away=team2 (라이브 카드 UI 컨벤션 유지).
    아직 시작하지 않은 게임(home/away 둘 다 null)은 포함하지 않는다.
    """
    sets: list[dict[str, Any]] = []
    for n in (1, 2, 3):
        home = _to_int(ld.get(f"team1_g{n}_score"))
        away = _to_int(ld.get(f"team2_g{n}_score"))
        if home is None and away is None:
            continue
        sets.append({"set": n, "home": home, "away": away})
    return sets


def _slug_from_url(url: Any) -> str | None:
    """bwfworldtour.../tournament/{tid}/{slug}/results/ 에서 slug 추출."""
    if not isinstance(url, str) or not url:
        return None
    parts = [p for p in url.split("/") if p]
    try:
        idx = parts.index("tournament")
    except ValueError:
        return None
    if idx + 2 < len(parts):
        return parts[idx + 2] or None
    return None


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


def _date_only(v: Any) -> str | None:
    if v is None:
        return None
    s = str(v).strip()
    if not s:
        return None
    return s.split(" ", 1)[0] or None
