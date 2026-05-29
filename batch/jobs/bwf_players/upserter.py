from typing import Any

from supabase import Client

CHUNK_SIZE = 200


def upsert_players(supabase: Client, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0
    written = 0
    for i in range(0, len(rows), CHUNK_SIZE):
        chunk = rows[i : i + CHUNK_SIZE]
        supabase.table("bwf_players").upsert(chunk, on_conflict="id").execute()
        written += len(chunk)
    return written
