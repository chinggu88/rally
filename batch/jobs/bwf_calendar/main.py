"""Crawl the BWF HSBC World Tour calendar and upsert into bwf_tournaments.

Stores every tournament the calendar API returns for category ids 20-27 —
including Super 100, Grade 1 Team & Individual events — so bwf_matches always has
a parent tournament to reference.
"""
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
    return transform_results(payload, year)


def run(year: int | None = None, dry_run: bool = False) -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    year = year or datetime.utcnow().year
    log.info(f"Starting {JOB_NAME} (year={year}, dry_run={dry_run})")

    supabase = None if dry_run else get_client()
    log_id = _start_log(supabase) if supabase else None

    try:
        rows = _collect_rows(year)
        levels = Counter(r["tour_level"] for r in rows)
        log.info(
            f"Parsed {len(rows)} tournaments. Levels:\n"
            + "\n".join(f"  {k}: {v}" for k, v in levels.items())
        )
        if not rows:
            raise RuntimeError("No tournaments parsed — calendar API shape may have changed")

        if dry_run:
            print(json.dumps(
                [{k: v for k, v in r.items() if k != "raw"} for r in rows],
                ensure_ascii=False, indent=2, default=str,
            ))
            return len(rows)

        written = upsert_tournaments(supabase, rows)
        log.info(f"Upserted {written} tournaments")
        _finish_log(
            supabase, log_id, status="success", rows_written=written,
            metadata={"year": year, "levels": dict(levels)},
        )
        return written

    except Exception as e:
        log.exception("Batch failed")
        if supabase and log_id is not None:
            _finish_log(
                supabase, log_id, status="failed", rows_written=0,
                error=f"{type(e).__name__}: {e}",
            )
        raise


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Crawl BWF HSBC World Tour calendar (all categories 20-27)"
    )
    p.add_argument("--year", type=int, default=None, help="Year to crawl (default: current year)")
    p.add_argument(
        "--dry-run", action="store_true",
        help="Print parsed tournaments as JSON; do not write to Supabase",
    )
    return p.parse_args()


def main() -> None:
    args = _parse_args()
    run(year=args.year, dry_run=args.dry_run)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit(1)
