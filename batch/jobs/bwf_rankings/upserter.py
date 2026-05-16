from typing import Any

from supabase import Client

CHUNK_SIZE = 500


def upsert_rankings(supabase: Client, rows: list[dict[str, Any]]) -> int:
    if not rows:
        return 0

    deduped = _dedupe_by_key(rows)
    written = 0
    for i in range(0, len(deduped), CHUNK_SIZE):
        chunk = deduped[i : i + CHUNK_SIZE]
        supabase.table("bwf_rankings").upsert(
            chunk, on_conflict="category,member_id"
        ).execute()
        written += len(chunk)
    return written


def _dedupe_by_key(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Keep the best (lowest rank = best ranked) row per (category, member_id)."""
    seen: dict[tuple[str, str], dict[str, Any]] = {}
    for row in rows:
        key = (row["category"], row["member_id"])
        prev = seen.get(key)
        if prev is None or row["rank"] < prev["rank"]:
            seen[key] = row
    return list(seen.values())
