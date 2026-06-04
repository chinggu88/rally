import requests

NEWS_BASE = "https://www.badmintonplanet.com/badminton-news.html"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


def page_url(page: int) -> str:
    """기사 목록 페이지 URL. page 1은 기본 URL, 이후는 /page/N."""
    if page <= 1:
        return NEWS_BASE
    return f"{NEWS_BASE}/page/{page}"


def fetch_page_html(page: int, timeout: int = 30) -> str:
    """주어진 목록 페이지의 HTML을 반환한다."""
    r = requests.get(
        page_url(page),
        headers={"User-Agent": USER_AGENT, "Accept": "text/html"},
        timeout=timeout,
    )
    r.raise_for_status()
    return r.text
