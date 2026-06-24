"""Capture vue-live-matches JSON per tournament via a resident Playwright page.

왜 가로채기인가:
  - Cloudflare JA3 fingerprint 검사로 `requests`/`page.request`/`page.evaluate fetch`
    모두 403. SPA가 자기 컨텍스트에서 한 호출만 통과한다.
  - 그래서 match-centre SPA 페이지를 띄우고 `page.on("response")`로 SPA가
    호출하는 vue-live-matches 응답을 가로챈다.

사용 패턴:
    with LiveMatchCentreSession() as session:
        while True:
            for tid in active_tournament_ids:
                payload = session.fetch_live_matches(tid)
                ...
            time.sleep(POLL_INTERVAL)
"""
from __future__ import annotations

import time
from typing import Any

from playwright.sync_api import (
    Browser,
    BrowserContext,
    Page,
    Playwright,
    sync_playwright,
)

# SPA 진입점. 이 페이지를 띄우면 SPA가 vue-live-matches API를 자동 호출한다.
MATCH_CENTRE_URL = "https://match-centre.bwfbadminton.com/{tid}"

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

DEFAULT_GOTO_TIMEOUT_MS = 60_000
# SPA가 vue-live-matches를 호출하기까지 대기. 대부분 2~5초.
DEFAULT_CAPTURE_WAIT_MS = 15_000


class LiveMatchCentreSession:
    """Long-lived Playwright browser; per-call BrowserContext.

    BWF SPA는 컨텍스트의 cookie/IndexedDB/localStorage가 누적되면 N틱 후에
    "캐시된 빈 상태" 응답으로 락 걸리는 현상이 재현됨. 그래서 fetch 호출마다
    컨텍스트째 새로 만들어 storage를 완전 격리한다. 브라우저는 살려두어 시작
    비용은 최소화.
    """

    def __init__(self, headless: bool = True) -> None:
        self.headless = headless
        self._pw: Playwright | None = None
        self._browser: Browser | None = None

    # ---- context manager --------------------------------------------------

    def _new_ctx(self) -> BrowserContext:
        assert self._browser is not None
        return self._browser.new_context(
            user_agent=USER_AGENT,
            viewport={"width": 1440, "height": 900},
            locale="en-US",
        )

    def __enter__(self) -> "LiveMatchCentreSession":
        self._pw = sync_playwright().start()
        self._browser = self._pw.chromium.launch(headless=self.headless)
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        try:
            if self._browser is not None:
                self._browser.close()
        finally:
            if self._pw is not None:
                self._pw.stop()
            self._pw = None
            self._browser = None

    # ---- public api -------------------------------------------------------

    def fetch_live_matches(self, tournament_id: int) -> dict[str, Any] | None:
        """Capture vue-live-matches JSON for a tournament via a fresh context+page.

        반환 형태(예시):
            {"results": [{"live_detail": {...}, "match_detail": {...}}, ...]}

        결과가 없는 대회도 응답 자체는 200 + {"results": []} 형태로 돌아온다.
        캡처 실패 시 None.
        """
        if self._browser is None:
            raise RuntimeError("Session not entered.")

        ctx = self._new_ctx()
        page = ctx.new_page()
        try:
            return self._capture_endpoint(
                page,
                sig="match-center/vue-live-matches",
                url=MATCH_CENTRE_URL.format(tid=tournament_id),
            )
        finally:
            try:
                ctx.close()
            except Exception:
                pass

    # ---- internal ---------------------------------------------------------

    def _capture_endpoint(
        self,
        page: Page,
        sig: str,
        url: str,
        wait_ms: int = DEFAULT_CAPTURE_WAIT_MS,
    ) -> dict[str, Any] | None:
        captured: dict[str, Any] = {}

        def on_response(resp):
            if sig in resp.url and resp.status == 200 and "json" not in captured:
                try:
                    captured["json"] = resp.json()
                except Exception:
                    pass

        page.on("response", on_response)
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=DEFAULT_GOTO_TIMEOUT_MS)
            deadline = time.monotonic() + (wait_ms / 1000.0)
            while time.monotonic() < deadline and "json" not in captured:
                page.wait_for_timeout(250)
        finally:
            page.remove_listener("response", on_response)

        return captured.get("json")
