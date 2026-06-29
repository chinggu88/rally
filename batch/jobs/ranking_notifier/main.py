import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.ranking_notifier.detector import (
    expand_member_id,
    fetch_changed_rankings,
    fetch_interested_users,
    fetch_summary_notified_user_ids,
)
from batch.jobs.ranking_notifier.notifier import (
    build_summary_rows,
    insert_notifications,
)
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "ranking_notifier"
BATCH_ENV = Path(__file__).resolve().parents[2] / ".env"


def _start_log(supabase: Any) -> int:
    res = (
        supabase.table("batch_logs")
        .insert({"job": JOB_NAME, "status": "started"})
        .execute()
    )
    return res.data[0]["id"]


def _finish_log(
    supabase: Any,
    log_id: int,
    status: str,
    rows_written: int,
    error: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> None:
    payload: dict[str, Any] = {
        "status": status,
        "rows_written": rows_written,
        "finished_at": datetime.utcnow().isoformat() + "Z",
    }
    if error is not None:
        payload["error"] = error
    if metadata is not None:
        payload["metadata"] = metadata
    supabase.table("batch_logs").update(payload).eq("id", log_id).execute()


def _resolve_latest_week(supabase: Any) -> tuple[int, int]:
    """bwf_rankings에서 가장 최근 (year, week) 조회."""
    res = (
        supabase.table("bwf_rankings")
        .select("ranking_year, ranking_week")
        .order("ranking_year", desc=True)
        .order("ranking_week", desc=True)
        .limit(1)
        .execute()
    )
    rows = res.data or []
    if not rows:
        raise RuntimeError("bwf_rankings is empty; cannot infer latest week")
    return int(rows[0]["ranking_year"]), int(rows[0]["ranking_week"])


def run(year: int | None = None, week: int | None = None) -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    supabase = get_client()
    log_id = _start_log(supabase)

    notifications_inserted = 0
    changed_rankings = 0
    skipped_duplicate = 0

    try:
        if year is None or week is None:
            year, week = _resolve_latest_week(supabase)
        log.info(f"Target week: {year}-W{week}")

        changes = fetch_changed_rankings(supabase, year, week)
        changed_rankings = len(changes)
        log.info(f"Changed rankings: {changed_rankings}")

        # 유저별로 관심선수 변동 내역을 모은다 (유저당 요약 알림 1건).
        user_changes: dict[str, list[dict]] = {}
        for row in changes:
            player_ids = expand_member_id(row["member_id"])
            if not player_ids:
                continue
            user_ids = fetch_interested_users(supabase, player_ids)
            if not user_ids:
                continue
            change = {
                "member_id": row["member_id"],
                "player_name": row["player_name"],
                "category": row["category"],
                "rank": int(row["rank"]),
                "rank_change": int(row["rank_change"]),
            }
            for uid in user_ids:
                user_changes.setdefault(uid, []).append(change)

        already = fetch_summary_notified_user_ids(supabase, year, week)
        target = {
            uid: chs for uid, chs in user_changes.items() if uid not in already
        }
        skipped_duplicate = len(user_changes) - len(target)

        rows = build_summary_rows(target, year=year, week=week)
        notifications_inserted = insert_notifications(supabase, rows)
        for uid, chs in target.items():
            log.info(f"user {uid}: summary of {len(chs)} ranking changes")

        _finish_log(
            supabase,
            log_id,
            status="success",
            rows_written=notifications_inserted,
            metadata={
                "year": year,
                "week": week,
                "changed_rankings": changed_rankings,
                "notifications_inserted": notifications_inserted,
                "unique_users": len(target),
                "skipped_duplicate": skipped_duplicate,
            },
        )
        log.info(
            f"Done. inserted={notifications_inserted} "
            f"unique_users={len(target)} skipped_dup={skipped_duplicate}"
        )
        return notifications_inserted
    except Exception as e:
        log.exception("Batch failed")
        _finish_log(
            supabase,
            log_id,
            status="failed",
            rows_written=notifications_inserted,
            error=f"{type(e).__name__}: {e}",
            metadata={
                "year": year,
                "week": week,
                "changed_rankings": changed_rankings,
                "notifications_inserted": notifications_inserted,
            },
        )
        raise


if __name__ == "__main__":
    try:
        run()
    except Exception:
        sys.exit(1)
