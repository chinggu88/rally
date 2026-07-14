import re
from typing import Any

from bs4 import BeautifulSoup

# tab0 = 試合結果(경기 결과) 탭만 수집한다.
CATEGORY = "試合結果"
SOURCE = "smash-net.tv"

_YEAR_CLASS = re.compile(r"^tab0-(\d{4})$")
_DATE = re.compile(r"^(\d{2})月(\d{2})日$")


def _to_iso8601(year: int, date_text: str) -> str | None:
    """(2026, '07月05日') → '2026-07-05T00:00:00+09:00' (일본시간, 시각 미제공)."""
    m = _DATE.match(date_text.strip())
    if not m:
        return None
    return f"{year}-{m.group(1)}-{m.group(2)}T00:00:00+09:00"


def parse_articles(html: str, min_year: int) -> list[dict[str, Any]]:
    """새소식 페이지에서 試合結果 탭의 min_year 이후 기사를 파싱한다.

    구조: div#tab0 > div.tab0-YYYY > ul.topics001-news > li > a
    (a 안에 h3.date '07月05日', p.msg 제목)
    반환 dict: url, title, author, category, published_at, source, raw.
    """
    soup = BeautifulSoup(html, "html.parser")
    tab0 = soup.select_one("div#tab0")
    if tab0 is None:
        return []

    articles: list[dict[str, Any]] = []
    seen: set[str] = set()

    for block in tab0.find_all("div", class_=_YEAR_CLASS):
        year = int(_YEAR_CLASS.match(block["class"][0]).group(1))
        if year < min_year:
            continue

        for a in block.select("ul.topics001-news li a[href]"):
            url = a["href"].strip()
            if not url or url in seen:
                continue

            msg = a.select_one("p.msg")
            title = msg.get_text(strip=True) if msg else ""
            if not title:
                continue
            seen.add(url)

            date_el = a.select_one("h3.date")
            date_text = date_el.get_text(strip=True) if date_el else ""

            articles.append(
                {
                    "url": url,
                    "title": title,
                    "author": None,
                    "category": CATEGORY,
                    "published_at": _to_iso8601(year, date_text),
                    "source": SOURCE,
                    "raw": {
                        "year": year,
                        "date": date_text,
                        "category": CATEGORY,
                    },
                }
            )

    return articles
