import argparse
import json
import sys
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.bwf_calendar.fetcher import (
    browser_page,
    extract_api_token,
    fetch_year_tournaments,
)
from batch.jobs.bwf_calendar.parser import transform_results
from batch.jobs.bwf_calendar.upserter import upsert_tournaments
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "bwf_calendar"
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


def _collect_rows(year: int) -> list[dict[str, Any]]:
    with browser_page() as page:
        token = extract_api_token(page)
    payload = fetch_year_tournaments(token, year)
    return transform_results(payload, year=year)


def run(year: int, dry_run: bool) -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    log.info(f"Starting bwf_calendar (year={year}, dry_run={dry_run})")

    if dry_run:
        rows = _collect_rows(year)
        levels = Counter(r["tour_level"] for r in rows)
        log.info(f"Parsed {len(rows)} tournaments. Levels: {dict(levels)}")
        json.dump(
            {"count": len(rows), "levels": dict(levels), "tournaments": rows},
            sys.stdout,
            indent=2,
            ensure_ascii=False,
            default=str,
        )
        sys.stdout.write("\n")
        return len(rows)

    supabase = get_client()
    log_id = _start_log(supabase)
    written = 0
    levels: Counter[str] = Counter()
    try:
        rows = _collect_rows(year)
        if not rows:
            raise RuntimeError(
                "No tournaments parsed — calendar API shape may have changed"
            )
        levels = Counter(r["tour_level"] for r in rows)
        written = upsert_tournaments(supabase, rows)
        log.info(f"Upserted {written} tournaments. Levels: {dict(levels)}")

        _finish_log(
            supabase,
            log_id,
            status="success",
            rows_written=written,
            metadata={"year": year, "tour_levels_count": dict(levels)},
        )
        return written
    except Exception as e:
        log.exception("Batch failed")
        _finish_log(
            supabase,
            log_id,
            status="failed",
            rows_written=written,
            error=f"{type(e).__name__}: {e}",
            metadata={"year": year, "tour_levels_count": dict(levels)},
        )
        raise


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Crawl BWF HSBC World Tour calendar (Finals + Super 1000/750/500/300)"
    )
    parser.add_argument(
        "--year",
        type=int,
        default=datetime.now().year,
        help="Year to crawl (default: current year)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print parsed tournaments as JSON; do not write to Supabase",
    )
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    try:
        run(year=args.year, dry_run=args.dry_run)
    except Exception:
        sys.exit(1)


if __name__ == "__main__":
    main()
