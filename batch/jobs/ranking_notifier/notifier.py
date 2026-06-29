from typing import Any

from batch.jobs.ranking_notifier.messages import build_summary_message

CHUNK_SIZE = 500


def build_summary_rows(
    user_changes: dict[str, list[dict]], year: int, week: int
) -> list[dict]:
    """유저별 랭킹변동 목록 → 유저당 요약 알림 row 1건."""
    title, body = build_summary_message()
    rows: list[dict] = []
    for uid, changes in user_changes.items():
        if not changes:
            continue
        rows.append(
            {
                "user_id": uid,
                "title": title,
                "body": body,
                "data": {
                    "type": "ranking_change",
                    "ranking_year": str(year),
                    "ranking_week": str(week),
                    "count": len(changes),
                    "changes": changes,
                },
                "status": "pending",
            }
        )
    return rows


def insert_notifications(supabase: Any, rows: list[dict]) -> int:
    if not rows:
        return 0
    written = 0
    for i in range(0, len(rows), CHUNK_SIZE):
        chunk = rows[i : i + CHUNK_SIZE]
        supabase.table("notifications").insert(chunk).execute()
        written += len(chunk)
    return written
