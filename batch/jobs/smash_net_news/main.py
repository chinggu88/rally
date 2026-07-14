import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.smash_net_news.fetcher import fetch_topic_html
from batch.jobs.smash_net_news.parser import parse_articles
from batch.jobs.smash_net_news.upserter import fetch_existing_urls, upsert_news
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "smash_net_news"

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

    # 페이지에 2008년부터 전체 기사가 있으므로 기본은 올해만. 백필 시 NEWS_MIN_YEAR 를 낮춘다.
    min_year = int(os.environ.get("NEWS_MIN_YEAR", datetime.now().year))

    log = get_logger(JOB_NAME)
    supabase = get_client()
    log_id = _start_log(supabase)

    new_rows: list[dict[str, Any]] = []

    try:
        existing = fetch_existing_urls(supabase)
        log.info(f"Existing articles in DB: {len(existing)}")

        html = fetch_topic_html()
        articles = parse_articles(html, min_year=min_year)
        new_rows = [a for a in articles if a["url"] not in existing]
        log.info(
            f"min_year {min_year}: {len(articles)} articles, {len(new_rows)} new"
        )

        written = upsert_news(supabase, new_rows)
        _finish_log(
            supabase,
            log_id,
            status="success",
            rows_written=written,
            metadata={
                "min_year": min_year,
                "articles_parsed": len(articles),
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
            rows_written=0,
            error=f"{type(e).__name__}: {e}",
        )
        raise


if __name__ == "__main__":
    try:
        run()
    except Exception:
        sys.exit(1)
