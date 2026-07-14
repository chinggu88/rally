import requests

# 새소식 페이지 한 장에 전체 연도(2008~) 기사가 모두 들어 있다 (페이지네이션 없음).
TOPIC_URL = "https://www.smash-net.tv/topic/"
USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)


def fetch_topic_html(timeout: int = 30) -> str:
    """새소식 목록 페이지의 HTML을 반환한다."""
    r = requests.get(
        TOPIC_URL,
        headers={"User-Agent": USER_AGENT, "Accept": "text/html"},
        timeout=timeout,
    )
    r.raise_for_status()
    return r.text
