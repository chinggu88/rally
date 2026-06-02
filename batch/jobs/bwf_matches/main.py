"""Crawl BWF tournament match data for a year and upsert into bwf_matches.

For each tournament in the year's HSBC World Tour calendar:
  - classify lifecycle from live_status -> pre (대회전) | live (대회중) | post (대회후)
  - fetch its discipline draws (MS/WS/MD/WD/XD)
  - fetch the matches array for each draw
  - parse + buffer + upsert

Future tournaments with no published draw simply yield 0 matches and are skipped.
"""
import argparse
import json
import os
import random
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.bwf_matches.fetcher import (
    api_session,
    fetch_draw_matches,
    fetch_tournament_draws,
    fetch_year_calendar,
)
from batch.jobs.bwf_matches.parser import normalize_status, parse_match
from batch.jobs.bwf_matches.upserter import dedupe_by_id, upsert_matches
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "bwf_matches"

REQUEST_DELAY_RANGE = (0.3, 0.7)
FLUSH_EVERY = 500
CONSECUTIVE_FAILURE_LIMIT = 15

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


def _crawl(
    session: Any,
    tournaments: list[dict[str, Any]],
    log: Any,
) -> tuple[list[dict[str, Any]], Counter, Counter, int]:
    """Fetch + parse all matches for the given tournaments.

    Returns (rows, status_counter, event_counter, failed_draws).
    """
    rows: list[dict[str, Any]] = []
    status_counter: Counter = Counter()
    event_counter: Counter = Counter()
    failed_draws = 0
    consecutive_failures = 0
    total = len(tournaments)

    for idx, t in enumerate(tournaments, start=1):
        tmt_id = t.get("id")
        if not isinstance(tmt_id, int):
            continue
        tournament_status = normalize_status(t.get("live_status"))

        try:
            draws = fetch_tournament_draws(session, tmt_id)
            consecutive_failures = 0
        except Exception as e:
            failed_draws += 1
            consecutive_failures += 1
            log.warning(f"[{idx}/{total}] draws failed id={tmt_id}: {type(e).__name__}: {e}")
            if consecutive_failures >= CONSECUTIVE_FAILURE_LIMIT:
                raise RuntimeError("Too many consecutive failures (token expired?)")
            continue

        if not draws:
            log.info(f"[{idx}/{total}] {t.get('name')} ({tournament_status}) — no draws yet")
            continue

        match_count = 0
        for draw in draws:
            draw_id = draw.get("value")
            if draw_id is None:
                continue
            try:
                matches = fetch_draw_matches(session, tmt_id, str(draw_id))
                consecutive_failures = 0
            except Exception as e:
                failed_draws += 1
                consecutive_failures += 1
                log.warning(
                    f"[{idx}/{total}] draw-data failed id={tmt_id} draw={draw_id}: "
                    f"{type(e).__name__}: {e}"
                )
                if consecutive_failures >= CONSECUTIVE_FAILURE_LIMIT:
                    raise RuntimeError("Too many consecutive failures (token expired?)")
                continue

            for m in matches:
                row = parse_match(m, t, draw, tournament_status)
                if row is None:
                    continue
                rows.append(row)
                match_count += 1
                event_counter[row["event_name"]] += 1

            time.sleep(random.uniform(*REQUEST_DELAY_RANGE))

        status_counter[tournament_status] += 1
        log.info(
            f"[{idx}/{total}] {t.get('name')} ({tournament_status}) — "
            f"{match_count} matches across {len(draws)} draws"
        )

    return rows, status_counter, event_counter, failed_draws


def run(year: int | None = None, dry_run: bool = False, tournament_id: int | None = None) -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    year = year or datetime.utcnow().year
    log.info(f"Starting {JOB_NAME} (year={year}, dry_run={dry_run}, tournament_id={tournament_id})")

    supabase = None if dry_run else get_client()
    log_id = _start_log(supabase) if supabase else None
    written = 0

    try:
        session = api_session()

        tournaments = fetch_year_calendar(session, year)
        log.info(f"Calendar: {len(tournaments)} tournaments in {year}")
        if tournament_id is not None:
            tournaments = [t for t in tournaments if t.get("id") == tournament_id]
            log.info(f"Filtered to tournament_id={tournament_id}: {len(tournaments)} match(es)")
        if not tournaments:
            raise RuntimeError("No tournaments to crawl")

        # Optional cap for smoke tests: BWF_MATCHES_LIMIT=3
        limit = os.environ.get("BWF_MATCHES_LIMIT")
        if limit and limit.isdigit():
            tournaments = tournaments[: int(limit)]
            log.info(f"BWF_MATCHES_LIMIT={limit} — crawling {len(tournaments)} tournaments")

        rows, status_counter, event_counter, failed_draws = _crawl(session, tournaments, log)
        rows = dedupe_by_id(rows)
        log.info(
            f"Parsed {len(rows)} matches. "
            f"Tournaments by status: {dict(status_counter)}. "
            f"Matches by event: {dict(event_counter)}. failed_draws={failed_draws}"
        )

        if dry_run:
            sample = [
                {k: v for k, v in r.items() if k != "raw"}
                for r in rows[:5]
            ]
            print(json.dumps(sample, ensure_ascii=False, indent=2, default=str))
            log.info("dry-run — nothing written")
            return len(rows)

        # Flush in chunks to keep memory flat on full-year runs.
        for i in range(0, len(rows), FLUSH_EVERY):
            written += upsert_matches(supabase, rows[i : i + FLUSH_EVERY])
            log.info(f"flushed — written={written}/{len(rows)}")

        _finish_log(
            supabase,
            log_id,
            status="success",
            rows_written=written,
            metadata={
                "year": year,
                "tournaments": len(tournaments),
                "matches": len(rows),
                "by_status": dict(status_counter),
                "by_event": dict(event_counter),
                "failed_draws": failed_draws,
            },
        )
        log.info(f"Done. written={written}")
        return written

    except Exception as e:
        log.exception("Batch failed")
        if supabase and log_id is not None:
            _finish_log(
                supabase,
                log_id,
                status="failed",
                rows_written=written,
                error=f"{type(e).__name__}: {e}",
            )
        raise


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="Crawl BWF tournament match data into bwf_matches "
        "(대회전/대회중/대회후 classified by live_status)"
    )
    p.add_argument("--year", type=int, default=None, help="Year to crawl (default: current)")
    p.add_argument(
        "--tournament-id", type=int, default=None, help="Crawl only this tournament id"
    )
    p.add_argument(
        "--dry-run", action="store_true", help="Print sample matches; do not write to Supabase"
    )
    return p.parse_args()


def main() -> None:
    args = _parse_args()
    run(year=args.year, dry_run=args.dry_run, tournament_id=args.tournament_id)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        sys.exit(1)
