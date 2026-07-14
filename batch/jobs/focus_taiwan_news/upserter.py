from typing import Any

from supabase import Client

from batch.jobs.focus_taiwan_news.parser import SOURCE

TABLE = "badminton_planet_news"
CHUNK_SIZE = 500


def fetch_existing_urls(supabase: Client) -> set[str]:
    """이미 저장된 focustaiwan.tw 기사 url 집합. 신규 기사 판별에 사용."""
    urls: set[str] = set()
    page_size = 1000
    start = 0
    while True:
        res = (
            supabase.table(TABLE)
            .select("url")
            .eq("source", SOURCE)
            .range(start, start + page_size - 1)
            .execute()
        )
        rows = res.data or []
        for row in rows:
            urls.add(row["url"])
        if len(rows) < page_size:
            break
        start += page_size
    return urls


def upsert_news(supabase: Client, rows: list[dict[str, Any]]) -> int:
    """url 충돌 기준 upsert. 쓴 행 수를 반환."""
    if not rows:
        return 0

    deduped = list({row["url"]: row for row in rows}.values())
    written = 0
    for i in range(0, len(deduped), CHUNK_SIZE):
        chunk = deduped[i : i + CHUNK_SIZE]
        supabase.table(TABLE).upsert(chunk, on_conflict="url").execute()
        written += len(chunk)
    return written
