import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

NEWS_BASE = "https://www.badmintonplanet.com/badminton-news.html"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

# 목록 페이지가 서버 캐시에 없으면 첫 응답까지 15~20초가 걸리고 가끔 30초를
# 넘긴다. 타임아웃을 넉넉히 주고, 읽기 타임아웃/5xx 는 1s/2s/4s 백오프로 재시도.
READ_TIMEOUT_SEC = 90
RETRY_TOTAL = 3
RETRY_BACKOFF_FACTOR = 1.0
RETRY_STATUS_FORCELIST = (429, 500, 502, 503, 504)


def page_url(page: int) -> str:
    """기사 목록 페이지 URL. page 1은 기본 URL, 이후는 /page/N."""
    if page <= 1:
        return NEWS_BASE
    return f"{NEWS_BASE}/page/{page}"


def _session() -> requests.Session:
    s = requests.Session()
    s.headers.update({"User-Agent": USER_AGENT, "Accept": "text/html"})
    retry = Retry(
        total=RETRY_TOTAL,
        backoff_factor=RETRY_BACKOFF_FACTOR,
        status_forcelist=RETRY_STATUS_FORCELIST,
        allowed_methods=frozenset(["GET"]),
        raise_on_status=False,
    )
    s.mount("https://", HTTPAdapter(max_retries=retry))
    return s


def fetch_page_html(page: int, timeout: int = READ_TIMEOUT_SEC) -> str:
    """주어진 목록 페이지의 HTML을 반환한다."""
    r = _session().get(page_url(page), timeout=timeout)
    r.raise_for_status()
    return r.text
