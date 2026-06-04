from typing import Any

from bs4 import BeautifulSoup


def parse_articles(html: str) -> list[dict[str, Any]]:
    """목록 페이지 HTML에서 기사 카드를 파싱한다.

    각 카드는 td-meta-info-container 안의 h3.entry-title > a 로 식별된다.
    반환 dict: url, title, author, category, published_at, raw.
    """
    soup = BeautifulSoup(html, "html.parser")
    articles: list[dict[str, Any]] = []
    seen: set[str] = set()

    for h3 in soup.select("h3.entry-title"):
        link = h3.find("a", href=True)
        if not link:
            continue
        url = link["href"].strip()
        if not url or url in seen:
            continue
        seen.add(url)

        title = (link.get("title") or link.get_text(strip=True)).strip()
        if not title:
            continue

        card = h3.find_parent(class_="td-meta-info-container") or h3.parent

        author = None
        category = None
        published_at = None
        if card is not None:
            a_author = card.select_one(".td-post-author-name a")
            if a_author:
                author = a_author.get_text(strip=True) or None
            a_cat = card.select_one(".td-post-category")
            if a_cat:
                category = a_cat.get_text(strip=True) or None
            t = card.select_one("time[datetime]")
            if t and t.get("datetime"):
                published_at = t["datetime"].strip()

        articles.append(
            {
                "url": url,
                "title": title,
                "author": author,
                "category": category,
                "published_at": published_at,
                "raw": {
                    "author": author,
                    "category": category,
                    "published_at": published_at,
                },
            }
        )

    return articles
