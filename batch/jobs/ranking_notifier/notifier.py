from typing import Any

from batch.jobs.ranking_notifier.messages import build_message

CHUNK_SIZE = 500


def build_notification_rows(
    user_ids: list[str], ranking_row: dict, year: int, week: int
) -> list[dict]:
    if not user_ids:
        return []
    title, body = build_message(ranking_row)
    data = {
        "type": "ranking_change",
        "category": ranking_row["category"],
        "member_id": ranking_row["member_id"],
        "rank": str(ranking_row["rank"]),
        "rank_change": str(ranking_row["rank_change"]),
        "ranking_year": str(year),
        "ranking_week": str(week),
    }
    return [
        {
            "user_id": uid,
            "title": title,
            "body": body,
            "data": data,
            "status": "pending",
        }
        for uid in user_ids
    ]


def insert_notifications(supabase: Any, rows: list[dict]) -> int:
    if not rows:
        return 0
    written = 0
    for i in range(0, len(rows), CHUNK_SIZE):
        chunk = rows[i : i + CHUNK_SIZE]
        supabase.table("notifications").insert(chunk).execute()
        written += len(chunk)
    return written
