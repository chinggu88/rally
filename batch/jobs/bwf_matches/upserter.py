from typing import Any

from supabase import Client

CHUNK_SIZE = 200


def upsert_matches(supabase: Client, rows: list[dict[str, Any]]) -> int:
    """Upsert match rows on `id` (the stable BWF match id), chunked."""
    if not rows:
        return 0
    written = 0
    for i in range(0, len(rows), CHUNK_SIZE):
        chunk = rows[i : i + CHUNK_SIZE]
        supabase.table("bwf_matches").upsert(chunk, on_conflict="id").execute()
        written += len(chunk)
    return written


def dedupe_by_id(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Keep the last occurrence per match id (a match can surface in two draws'
    bracket cells, but the matches array is per-draw so this is defensive)."""
    seen: dict[int, dict[str, Any]] = {}
    for row in rows:
        seen[row["id"]] = row
    return list(seen.values())
