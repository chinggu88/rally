from typing import Any

from supabase import Client


def upsert_tournaments(supabase: Client, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0
    rows = _dedupe_by_key(rows)
    supabase.table("bwf_tournaments").upsert(rows, on_conflict="tournament_id").execute()
    return len(rows)


def _dedupe_by_key(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Keep the last occurrence per tournament_id (defensive — the API rarely duplicates)."""
    seen: dict[int, dict[str, Any]] = {}
    for row in rows:
        seen[row["tournament_id"]] = row
    return list(seen.values())
