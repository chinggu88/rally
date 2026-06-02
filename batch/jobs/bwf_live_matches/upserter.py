"""Upsert parent tournaments + live matches; sweep ended matches.

각 라이브 대회의 메타는 bwf_tournaments에 upsert (FK 부모 보장)하고, 그 대회
results 페이지에서 긁어온 라이브 카드들은 bwf_live_matches에 매치당 1행으로
upsert. 라이브에서 사라진 매치 행은 promoted_at에 시각을 박는다.
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


def upsert_live_matches(supabase: Client, matches: list[dict[str, Any]]) -> int:
    if not matches:
        return 0
    written = 0
    for i in range(0, len(matches), CHUNK_SIZE):
        chunk = matches[i : i + CHUNK_SIZE]
        supabase.table("bwf_live_matches").upsert(chunk, on_conflict="id").execute()
        written += len(chunk)
    return written


def mark_ended(supabase: Client, active_match_ids: Iterable[int], log) -> int:
    """현재 라이브 응답에 없는 매치 행을 종료 처리.

    종료 시그널 두 컬럼 동시 갱신:
      - promoted_at = now()  (감사용 종료 시각)
      - tournament_status = 'post'  (단일 컬럼 필터로 라이브 vs 종료 구분)

    라이브로 다시 잡히면 upsert path에서 tournament_status='live' + promoted_at
    NULL로 자연 복구된다(parser가 매 row에 두 값을 그렇게 박는다).
    """
    now = datetime.now(timezone.utc).isoformat()

    q = (
        supabase.table("bwf_live_matches")
        .update({"promoted_at": now, "tournament_status": "post"})
        .eq("tournament_status", "live")
        .is_("promoted_at", "null")
    )
    ids = list(active_match_ids)
    if ids:
        q = q.not_.in_("id", ids)
    res = q.execute()
    n = len(res.data) if getattr(res, "data", None) else 0
    if n:
        log.info(f"Marked {n} match-row(s) as ended (status='post')")
    return n
