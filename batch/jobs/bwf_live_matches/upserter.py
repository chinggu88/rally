"""Upsert parent tournaments + live matches; sweep ended matches.

각 라이브 대회의 메타는 bwf_tournaments에 upsert (FK 부모 보장)하고, 그 대회
results 페이지에서 긁어온 라이브 카드들은 bwf_live_matches에 매치당 1행으로
upsert. 라이브에서 사라진 매치 행은 promoted_at에 시각을 박는다.

설계 노트 — match_code 흐름:
  results 페이지 카드(parser)는 BWF match_code(GUID)를 노출하지 않는다.
  또한 카드 href의 /match/{id}와 bwf_matches.id는 **서로 다른 ID 체계**라서
  id로 join하면 매치를 찾지 못한다.

  대신 (tournament_id, event_name, team1_player_ids, team2_player_ids) 4-튜플로
  bwf_matches를 룩업한다 — 같은 대회·종목 안에서 두 팀 선수 ID 조합은 유일하다.
  팀 순서가 뒤집혀 들어올 수 있으니 양방향 매칭을 본다.

  라이브에서 사라진 매치는 종료된 것으로 보고, 같은 4-튜플로 다시 룩업해
  bwf_matches.score를 라이브 시점 마지막 score로 동기화한 뒤 bwf_live_matches는
  status='post' + promoted_at으로 소프트 삭제한다(히스토리/UX 보존).
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Iterable

from supabase import Client

CHUNK_SIZE = 200


def upsert_parents(supabase: Client, parents: list[dict[str, Any]]) -> int:
    if not parents:
        return 0
    supabase.table("bwf_tournaments").upsert(
        parents, on_conflict="tournament_id"
    ).execute()
    return len(parents)


def _team_key(ids: Any) -> tuple[int, ...] | None:
    """선수 ID 리스트를 정렬된 tuple로 정규화. 없으면 None."""
    if not isinstance(ids, list) or not ids:
        return None
    try:
        return tuple(sorted(int(x) for x in ids if x is not None))
    except (TypeError, ValueError):
        return None


def _match_key(
    tournament_id: Any,
    event_name: Any,
    team1_player_ids: Any,
    team2_player_ids: Any,
) -> tuple | None:
    """match_code 룩업용 정규화 키. (tid, event, frozenset({team1, team2})).

    팀 순서가 뒤집혀 들어올 수 있어 양 팀을 frozenset으로 묶는다(순서 무관).
    """
    if not isinstance(tournament_id, int) or not event_name:
        return None
    t1 = _team_key(team1_player_ids)
    t2 = _team_key(team2_player_ids)
    if t1 is None or t2 is None:
        return None
    return (tournament_id, str(event_name), frozenset({t1, t2}))


def _fetch_match_code_map(
    supabase: Client,
    tournament_ids: set[int],
) -> dict[tuple, str]:
    """주어진 tournament_id 집합의 모든 bwf_matches를 한 번에 가져와 키 매핑 생성."""
    code_by_key: dict[tuple, str] = {}
    if not tournament_ids:
        return code_by_key
    tids = list(tournament_ids)
    for i in range(0, len(tids), CHUNK_SIZE):
        chunk_tids = tids[i : i + CHUNK_SIZE]
        res = (
            supabase.table("bwf_matches")
            .select(
                "match_code, tournament_id, event_name, "
                "team1_player_ids, team2_player_ids"
            )
            .in_("tournament_id", chunk_tids)
            .execute()
        )
        for row in getattr(res, "data", None) or []:
            code = row.get("match_code")
            if not code:
                continue
            key = _match_key(
                row.get("tournament_id"),
                row.get("event_name"),
                row.get("team1_player_ids"),
                row.get("team2_player_ids"),
            )
            if key is not None:
                code_by_key[key] = str(code)
    return code_by_key


def _hydrate_match_codes(
    supabase: Client,
    matches: list[dict[str, Any]],
) -> int:
    """bwf_matches에서 (tournament_id, event_name, 양 팀 선수 ID set) → match_code
    매핑을 조회해 라이브 row의 match_code 자리에 채워 넣는다.

    카드 href의 /match/{id}와 bwf_matches.id는 서로 다른 ID 체계라서 id 조인이
    불가하다. 같은 대회·종목 안에서 두 팀 선수 ID 조합은 유일하다는 성질을 활용
    한다(사용자가 보낸 확인 SQL과 동일한 키).
    """
    tournament_ids: set[int] = set()
    for m in matches:
        tid = m.get("tournament_id")
        if isinstance(tid, int):
            tournament_ids.add(tid)
    if not tournament_ids:
        return 0

    code_by_key = _fetch_match_code_map(supabase, tournament_ids)
    filled = 0
    for m in matches:
        key = _match_key(
            m.get("tournament_id"),
            m.get("event_name"),
            m.get("team1_player_ids"),
            m.get("team2_player_ids"),
        )
        if key is not None and key in code_by_key:
            m["match_code"] = code_by_key[key]
            filled += 1
    return filled


def upsert_live_matches(supabase: Client, matches: list[dict[str, Any]]) -> int:
    if not matches:
        return 0
    _hydrate_match_codes(supabase, matches)
    written = 0
    for i in range(0, len(matches), CHUNK_SIZE):
        chunk = matches[i : i + CHUNK_SIZE]
        supabase.table("bwf_live_matches").upsert(chunk, on_conflict="id").execute()
        written += len(chunk)
    return written


def _sync_scores_to_bwf_matches(
    supabase: Client,
    rows: list[dict[str, Any]],
    log,
) -> int:
    """종료 시점의 라이브 score를 bwf_matches로 옮긴다(match_code 기준 조인).

    `rows`는 bwf_live_matches에서 막 종료 처리된 행들(id/match_code/score). 같은
    BWF match_code를 가진 bwf_matches row의 score 컬럼을 라이브 마지막 score로
    덮어쓴다. match_code가 비어있는 행은 건너뛴다(아직 bwf_matches에 적재되기
    전이라는 뜻 — 다음 bwf_matches 잡이 받아갈 것).
    """
    updated = 0
    for r in rows:
        code = r.get("match_code")
        score = r.get("score")
        if not code:
            continue
        try:
            supabase.table("bwf_matches").update({"score": score}).eq(
                "match_code", code
            ).execute()
            updated += 1
        except Exception as e:
            log.warning(
                f"score sync failed for match_code={code}: {type(e).__name__}: {e}"
            )
    return updated


def mark_ended(
    supabase: Client,
    active_match_ids: Iterable[int],
    log,
    polled_tournament_ids: Iterable[int] | None = None,
) -> int:
    """현재 라이브 응답에 없는 매치 행을 종료 처리.

    [polled_tournament_ids] 이번 틱에 results 페이지를 **정상 응답까지 받은**
    대회 id 집합. None/빈값이면 sweep 자체를 건너뛴다(전역 폭주 방지).
    카드가 0개라도 navigation이 성공했다면 "그 대회는 라이브가 끝났다"는
    신호로 본다 — SPA 캐시 락이나 네트워크 실패와 정상 종료를 구분하기 위해
    main.py가 try/except를 통과한 대회만 이 집합에 담아 호출한다.

    종료 흐름:
      1) 종료 후보 = polled_tournament_ids 안의 대회 중, active 리스트에 없고
         아직 'live'+promoted_at IS NULL인 row.
      2) match_code가 비어있으면 bwf_matches에서 한 번 더 룩업해 채운다
         (upsert 시점에 못 가져온 경우 대비).
      3) match_code 기준으로 bwf_matches.score를 라이브 마지막 score로 동기화.
      4) bwf_live_matches는 promoted_at=now + tournament_status='post'로
         소프트 삭제 (히스토리/UX 보존).

    라이브로 다시 잡히면 upsert path에서 tournament_status='live' + promoted_at
    NULL로 자연 복구된다(parser가 매 row에 두 값을 그렇게 박는다).
    """
    polled_tids = [tid for tid in (polled_tournament_ids or []) if isinstance(tid, int)]
    if not polled_tids:
        return 0

    now = datetime.now(timezone.utc).isoformat()

    # 1) 종료 후보 조회 — 정상 조회된 대회 경계 내에서만.
    q = (
        supabase.table("bwf_live_matches")
        .select(
            "id, match_code, score, tournament_id, event_name, "
            "team1_player_ids, team2_player_ids"
        )
        .eq("tournament_status", "live")
        .is_("promoted_at", "null")
        .in_("tournament_id", polled_tids)
    )
    ids = list(active_match_ids)
    if ids:
        q = q.not_.in_("id", ids)
    cand_res = q.execute()
    candidates: list[dict[str, Any]] = list(getattr(cand_res, "data", None) or [])
    if not candidates:
        return 0

    # 2) 누락된 match_code를 bwf_matches에서 한 번 더 룩업해 채운다
    #    (tournament_id, event_name, 양 팀 선수 ID set) 키로 조회.
    need_lookup = [c for c in candidates if not c.get("match_code")]
    if need_lookup:
        tournament_ids: set[int] = {
            c["tournament_id"]
            for c in need_lookup
            if isinstance(c.get("tournament_id"), int)
        }
        code_by_key = _fetch_match_code_map(supabase, tournament_ids)
        for c in need_lookup:
            key = _match_key(
                c.get("tournament_id"),
                c.get("event_name"),
                c.get("team1_player_ids"),
                c.get("team2_player_ids"),
            )
            if key is not None and key in code_by_key:
                c["match_code"] = code_by_key[key]

    # 3) score → bwf_matches 반영
    synced = _sync_scores_to_bwf_matches(supabase, candidates, log)

    # 4) bwf_live_matches 소프트 삭제
    end_ids = [c["id"] for c in candidates if isinstance(c.get("id"), int)]
    n = 0
    for i in range(0, len(end_ids), CHUNK_SIZE):
        chunk = end_ids[i : i + CHUNK_SIZE]
        res = (
            supabase.table("bwf_live_matches")
            .update({"promoted_at": now, "tournament_status": "post"})
            .in_("id", chunk)
            .execute()
        )
        n += len(getattr(res, "data", None) or [])

    if n:
        log.info(
            f"Marked {n} match-row(s) as ended (status='post'), "
            f"score synced to bwf_matches for {synced} match_code(s)"
        )
    return n
