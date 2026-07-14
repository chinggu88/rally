import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.focus_taiwan_news.fetcher import fetch_page
from batch.jobs.focus_taiwan_news.parser import parse_articles
from batch.jobs.focus_taiwan_news.upserter import fetch_existing_urls, upsert_news
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "focus_taiwan_news"

# BADMINTON 필터 특성상 대부분의 페이지가 0건이므로
# "신규 없음 = 따라잡음" 조기 종료 없이 max_pages 까지(또는 목록 끝까지) 훑는다.
DEFAULT_MAX_PAGES = 10
PAGE_DELAY_SEC = 1.0

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

    max_pages = int(os.environ.get("NEWS_MAX_PAGES", DEFAULT_MAX_PAGES))

    log = get_logger(JOB_NAME)
    supabase = get_client()
    log_id = _start_log(supabase)

    new_rows: list[dict[str, Any]] = []
    pages_crawled = 0

    try:
        existing = fetch_existing_urls(supabase)
        log.info(f"Existing articles in DB: {len(existing)}")
        seen_new: set[str] = set()

        for page in range(1, max_pages + 1):
            payload = fetch_page(page)
            items = (payload.get("ResultData") or {}).get("Items") or []
            pages_crawled = page
            if not items:
                log.info(f"page {page}: 0 items from API, stopping")
                break

            articles = parse_articles(payload)
            page_new = [
                a
                for a in articles
                if a["url"] not in existing and a["url"] not in seen_new
            ]
            for a in page_new:
                seen_new.add(a["url"])
            new_rows.extend(page_new)
            log.info(
                f"page {page}: {len(items)} items, "
                f"{len(articles)} badminton, {len(page_new)} new"
            )

            if page < max_pages:
                time.sleep(PAGE_DELAY_SEC)

        written = upsert_news(supabase, new_rows)
        _finish_log(
            supabase,
            log_id,
            status="success",
            rows_written=written,
            metadata={
                "pages_crawled": pages_crawled,
                "new_articles": len(new_rows),
                "existing_before": len(existing),
            },
        )
        log.info(f"Done. New articles upserted: {written}")
        return written
    except Exception as e:
        log.exception("Batch failed")
        _finish_log(
            supabase,
            log_id,
            status="failed",
            rows_written=len(new_rows),
            error=f"{type(e).__name__}: {e}",
            metadata={"pages_crawled": pages_crawled},
        )
        raise


if __name__ == "__main__":
    try:
        run()
    except Exception:
        sys.exit(1)
