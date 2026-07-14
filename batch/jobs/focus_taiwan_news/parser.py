from typing import Any

CATEGORY = "Badminton News"
SOURCE = "focustaiwan.tw"
TITLE_PREFIX = "BADMINTON"


def _to_iso8601(create_time: str) -> str | None:
    """'2026/07/12 19:09' (대만시간, UTC+8) → '2026-07-12T19:09:00+08:00'."""
    try:
        date_part, time_part = create_time.strip().split(" ")
        y, m, d = date_part.split("/")
        return f"{y}-{m}-{d}T{time_part}:00+08:00"
    except ValueError:
        return None


def parse_articles(payload: dict[str, Any]) -> list[dict[str, Any]]:
    """FTNewsList API 응답에서 제목이 BADMINTON으로 시작하는 기사만 추린다.

    반환 dict: url, title, author, category, published_at, source, raw.
    """
    items = (payload.get("ResultData") or {}).get("Items") or []
    articles: list[dict[str, Any]] = []

    for item in items:
        title = (item.get("HeadLine") or "").strip()
        url = (item.get("PageUrl") or "").strip()
        if not title or not url:
            continue
        if not title.upper().startswith(TITLE_PREFIX):
            continue

        articles.append(
            {
                "url": url,
                "title": title,
                "author": None,
                "category": CATEGORY,
                "published_at": _to_iso8601(item.get("CreateTime") or ""),
                "source": SOURCE,
                "raw": item,
            }
        )

    return articles
