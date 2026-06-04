import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.badminton_planet_news.fetcher import fetch_page_html
from batch.jobs.badminton_planet_news.parser import parse_articles
from batch.jobs.badminton_planet_news.upserter import fetch_existing_urls, upsert_news
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "badminton_planet_news"

# 최신 페이지부터 몇 페이지까지 훑을지 (신규가 없으면 그 전에 조기 종료).
# 최초 백필 시에는 NEWS_MAX_PAGES 를 크게 주면 된다.
DEFAULT_MAX_PAGES = 5
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
            html = fetch_page_html(page)
            articles = parse_articles(html)
            pages_crawled = page
            if not articles:
                log.info(f"page {page}: 0 articles parsed, stopping")
                break

            page_new = [
                a
                for a in articles
                if a["url"] not in existing and a["url"] not in seen_new
            ]
            for a in page_new:
                seen_new.add(a["url"])
            new_rows.extend(page_new)
            log.info(
                f"page {page}: {len(articles)} articles, {len(page_new)} new"
            )

            # 이 페이지에서 신규가 하나도 없으면 이미 따라잡은 것 → 종료.
            if not page_new:
                log.info(f"page {page}: no new articles, caught up")
                break

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
