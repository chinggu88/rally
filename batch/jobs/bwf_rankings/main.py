import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.bwf_rankings.fetcher import (
    browser_page,
    extract_api_token,
    fetch_all_pages,
    get_latest_publication,
)
from batch.jobs.bwf_rankings.parser import transform_rows
from batch.jobs.bwf_rankings.upserter import upsert_rankings
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "bwf_rankings"

# (category, catId). catId follows BWF World Rankings: 6=MS, 7=WS, 8=MD, 9=WD, 10=XD.
CATEGORIES: list[tuple[str, int]] = [
    ("MS", 6),
    ("WS", 7),
    ("MD", 8),
    ("WD", 9),
    ("XD", 10),
]

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


def _resolve_week(pub: dict[str, Any]) -> tuple[int, int]:
    year = pub.get("year") or pub.get("ranking_year")
    week = pub.get("week") or pub.get("ranking_week") or pub.get("week_number")
    if year is None or week is None:
        # Fallback: parse from publication name or date
        name = pub.get("name") or ""
        # e.g. "BWF World Rankings - 2026 Week 20"
        import re

        m = re.search(r"(\d{4}).*?(\d{1,2})", name)
        if m:
            year, week = int(m.group(1)), int(m.group(2))
    if year is None or week is None:
        raise RuntimeError(f"Cannot resolve year/week from publication: {pub}")
    return int(year), int(week)


def run() -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    supabase = get_client()
    log_id = _start_log(supabase)
    total = 0
    per_category: dict[str, int] = {}

    try:
        with browser_page() as page:
            token = extract_api_token(page)
            log.info(f"Got API token: {token[:20]}...")

        pub = get_latest_publication(token)
        year, week = _resolve_week(pub)
        pub_id = pub["id"]
        log.info(f"Latest publication: id={pub_id} year={year} week={week}")

        for cat, cat_id in CATEGORIES:
            log.info(f"Fetching {cat} (catId={cat_id})")
            raw_rows = list(
                fetch_all_pages(token, cat_id=cat_id, publication_id=pub_id)
            )
            log.info(f"{cat}: {len(raw_rows)} raw rows from API")

            rows = transform_rows(raw_rows, category=cat, year=year, week=week)
            if not rows:
                raise RuntimeError(f"No rows parsed for {cat}")

            written = upsert_rankings(supabase, rows)
            per_category[cat] = written
            total += written
            log.info(f"{cat}: upserted {written} rows")

        _finish_log(
            supabase,
            log_id,
            status="success",
            rows_written=total,
            metadata={
                "per_category": per_category,
                "publication_id": pub_id,
                "year": year,
                "week": week,
            },
        )
        log.info(f"Done. Total upserted: {total}")
        return total
    except Exception as e:
        log.exception("Batch failed")
        _finish_log(
            supabase,
            log_id,
            status="failed",
            rows_written=total,
            error=f"{type(e).__name__}: {e}",
            metadata={"per_category": per_category},
        )
        raise


if __name__ == "__main__":
    try:
        run()
    except Exception:
        sys.exit(1)
