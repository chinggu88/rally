import os
import random
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.bwf_players.fetcher import (
    api_session,
    backfill_ranking_player_ids,
    collect_detail_urls,
    fetch_player_bio,
    fetch_player_summary,
)
from batch.jobs.bwf_players.parser import parse_player
from batch.jobs.bwf_players.upserter import upsert_players
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "bwf_players"

# API calls (not HTML) — Cloudflare-free, so a light delay is enough to be polite.
REQUEST_DELAY_RANGE = (0.3, 0.7)
FLUSH_EVERY = 100
CONSECUTIVE_FAILURE_LIMIT = 15
PARTIAL_SUCCESS_THRESHOLD = 0.80

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


def run() -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    supabase = get_client()
    log_id = _start_log(supabase)
    written = 0
    fetched = 0
    failed = 0
    consecutive_failures = 0
    targets: list[tuple[int, str]] = []
    buffer: list[dict[str, Any]] = []

    try:
        targets = collect_detail_urls(supabase)
        log.info(f"Found {len(targets)} unique players in bwf_rankings")
        if not targets:
            raise RuntimeError("No players to crawl — is bwf_rankings empty?")

        # Optional cap for smoke-testing: BWF_PLAYERS_LIMIT=50
        limit = os.environ.get("BWF_PLAYERS_LIMIT")
        if limit and limit.isdigit():
            targets = targets[: int(limit)]
            log.info(f"BWF_PLAYERS_LIMIT={limit} — crawling only {len(targets)} players")
        total = len(targets)

        session = api_session()

        for idx, (player_id, detail_url) in enumerate(targets, start=1):
            try:
                summary = fetch_player_summary(session, player_id)
                if not summary:
                    raise RuntimeError("empty summary results")
                bio = fetch_player_bio(session, player_id)
                row = parse_player(summary, bio, player_id, detail_url)
                buffer.append(row)
                fetched += 1
                consecutive_failures = 0
            except Exception as e:
                failed += 1
                consecutive_failures += 1
                log.warning(
                    f"[{idx}/{total}] failed id={player_id}: {type(e).__name__}: {e}"
                )
                if consecutive_failures >= CONSECUTIVE_FAILURE_LIMIT:
                    raise RuntimeError(
                        f"Aborting after {consecutive_failures} consecutive failures "
                        "(token expired or API changed?)"
                    )

            if len(buffer) >= FLUSH_EVERY:
                written += upsert_players(supabase, buffer)
                log.info(f"[{idx}/{total}] flushed — written={written} fetched={fetched} failed={failed}")
                buffer.clear()

            time.sleep(random.uniform(*REQUEST_DELAY_RANGE))

        if buffer:
            written += upsert_players(supabase, buffer)
            buffer.clear()

        # Now that bwf_players is populated, the FK target exists — backfill
        # bwf_rankings.player1_id / player2_id from member_id in one round-trip.
        backfilled = backfill_ranking_player_ids(supabase)
        if backfilled is not None:
            log.info(f"Backfilled player ids on bwf_rankings: {backfilled} rows touched")
        else:
            log.warning("Backfill RPC unavailable or failed (player FK ids left as-is)")

        success_rate = fetched / total if total else 0.0
        status = "success" if success_rate >= PARTIAL_SUCCESS_THRESHOLD else "partial"

        _finish_log(
            supabase,
            log_id,
            status=status,
            rows_written=written,
            metadata={
                "total_targets": total,
                "fetched": fetched,
                "failed": failed,
                "success_rate": round(success_rate, 4),
                "rankings_backfilled": backfilled,
            },
        )
        log.info(f"Done. status={status} written={written} fetched={fetched}/{total} failed={failed}")
        return written

    except Exception as e:
        log.exception("Batch failed")
        if buffer:
            try:
                written += upsert_players(supabase, buffer)
            except Exception:
                log.exception("Final flush also failed")
        _finish_log(
            supabase,
            log_id,
            status="failed",
            rows_written=written,
            error=f"{type(e).__name__}: {e}",
            metadata={
                "total_targets": len(targets),
                "fetched": fetched,
                "failed": failed,
            },
        )
        raise


if __name__ == "__main__":
    try:
        run()
    except Exception:
        sys.exit(1)
