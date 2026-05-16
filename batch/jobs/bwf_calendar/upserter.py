from typing import Any

from supabase import Client

CHUNK_SIZE = 200


def upsert_tournaments(supabase: Client, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    deduped = _dedupe_by_key(rows)
    written = 0
    for i in range(0, len(deduped), CHUNK_SIZE):
        chunk = deduped[i : i + CHUNK_SIZE]
        supabase.table("bwf_tournaments").upsert(
            chunk, on_conflict="tournament_id"
        ).execute()
        written += len(chunk)
    return written


def _dedupe_by_key(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Keep the last occurrence per tournament_id (defensive — the API rarely duplicates)."""
    seen: dict[int, dict[str, Any]] = {}
    for row in rows:
        seen[row["tournament_id"]] = row
    return list(seen.values())
