"""Capture live-tournaments JSON via a resident Playwright page.

왜 가로채기인가:
  - BWF가 2026-06 기준 인증 모델을 바꾸었다 (Bearer 토큰 제거, GET 전환).
  - Cloudflare가 JA3 fingerprint를 검사해 `requests`/`page.request`/`page.evaluate fetch`
    모두 403. SPA가 자기 컨텍스트에서 한 호출만 통과.
  - 따라서 페이지를 띄워두고 `page.on("response")`로 SPA 응답을 가로챈다.

사용 패턴:
    with LiveCalendarSession() as session:
        while True:
            payload = session.fetch_current_live()   # 매 호출마다 reload + 캡처
            ...
            time.sleep(POLL_INTERVAL)

세션은 컨텍스트 매니저로 묶어 Playwright 브라우저 라이프사이클을 명시 관리한다.
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

# SPA 진입점. /calendar/2026/이 두 핵심 API(vue-current-live, vue-grouped-year-tournaments)를
# 한 번에 호출한다.
ENTRY_URL = "https://bwfworldtour.bwfbadminton.com/calendar/{year}/"
# 라이브 카드(`img[src*=live.svg]`)는 results/{YYYY-MM-DD} 페이지에 렌더된다.
TOURNAMENT_RESULTS_URL = (
    "https://bwfworldtour.bwfbadminton.com/tournament/{tid}/{slug}/results/{date}"
)

USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

DEFAULT_GOTO_TIMEOUT_MS = 60_000
# SPA가 API를 호출하기까지 대기하는 최대 시간 (대부분 2~5초 안에 옴).
DEFAULT_CAPTURE_WAIT_MS = 15_000
# results 페이지 SPA 렌더 대기 — Vue 컴포넌트가 카드를 그릴 때까지 폴링.
LIVE_CARDS_MAX_WAIT_MS = 25_000


# 라이브 카드 한 장의 구조화된 JSON을 만들어주는 in-page JS.
# 페이지가 로드된 직후에 평가해 모든 live.svg 카드를 수집한다.
EXTRACT_LIVE_CARDS_JS = r"""
() => {
    const liveImgs = Array.from(document.querySelectorAll('img'))
        .filter(i => /live\.svg/i.test(i.src || ''));
    return liveImgs.map(img => {
        const a = img.closest('a');
        if (!a) return null;
        const card = a.querySelector('.match-card') || a;
        const matchName = card.querySelector('.match-name')?.innerText?.trim() || null;
        const participants = Array.from(card.querySelectorAll('.participant-wrapper')).map(pw => {
            const flag = pw.querySelector('.flag');
            const playerLinks = Array.from(pw.querySelectorAll('a.participant-name'));
            const players = playerLinks.map(p => ({
                id: p.getAttribute('data-player'),
                country: p.getAttribute('data-country-code'),
                name: (p.innerText || '').trim(),
                url: p.href || null,
            }));
            const seed = pw.querySelector('span')?.innerText?.trim() || null;
            return {
                country: flag?.getAttribute('alt') || null,
                flagUrl: flag?.src || null,
                players,
                seed,
            };
        });
        // 점수: .game-score-set 마다 한 세트, set-points 가 두 개씩
        const sets = Array.from(card.querySelectorAll('.game-score-set')).map((s, idx) => {
            const pts = Array.from(s.querySelectorAll('.set-points')).map(p => p.innerText.trim());
            return {
                set: idx + 1,
                home: pts[0] != null ? parseInt(pts[0], 10) : null,
                away: pts[1] != null ? parseInt(pts[1], 10) : null,
            };
        });
        // 라스트 라인 그룹: 이벤트/라운드/코트/시간
        const text = (card.innerText || '');
        const lines = text.split('\n').map(l => l.trim()).filter(Boolean);
        const href = a.getAttribute('href') || '';
        const matchIdMatch = href.match(/\/match\/(\d+)/);
        const tournamentMatch = href.match(/match-centre\.bwfbadminton\.com\/(\d+)\//);
        return {
            matchId: matchIdMatch ? parseInt(matchIdMatch[1], 10) : null,
            tournamentId: tournamentMatch ? parseInt(tournamentMatch[1], 10) : null,
            href,
            matchName,
            participants,
            sets,
            lines,
        };
    }).filter(Boolean);
}
"""


class LiveCalendarSession:
    """Long-lived Playwright browser; per-call BrowserContext.

    BWF SPA(calendar/results 모두)는 컨텍스트의 cookie/IndexedDB/localStorage
    가 누적되면 N틱 후에 "캐시된 빈 상태" 응답으로 락 걸리는 현상이 재현됨.
    그래서 fetch 호출마다 컨텍스트째 새로 만들어 storage를 완전 격리한다.
    브라우저는 살려두어 시작 비용은 최소화.
    """

    def __init__(self, year: int, headless: bool = True) -> None:
        self.year = year
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

    def __enter__(self) -> "LiveCalendarSession":
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

    def fetch_current_live(self) -> dict[str, Any] | None:
        """Capture the vue-current-live JSON via a fresh context+page.

        results 페이지처럼 캘린더 SPA도 컨텍스트 storage가 누적되면 캐시 락에
        걸릴 가능성이 있어 매 호출마다 컨텍스트째 새로 만든다. 캘린더는 5분에
        한 번만 호출되므로 비용 부담 미미.
        """
        if self._browser is None:
            raise RuntimeError("Session not entered.")

        ctx = self._new_ctx()
        page = ctx.new_page()
        try:
            return self._capture_endpoint(
                page,
                sig="match-center/vue-current-live",
                url=ENTRY_URL.format(year=self.year),
            )
        finally:
            try:
                ctx.close()
            except Exception:
                pass

    def fetch_live_match_cards(
        self,
        tournament_id: int,
        slug: str,
        date: str,
    ) -> list[dict[str, Any]]:
        """Render results/{date} in a fresh context+page and extract live cards.

        Fresh context per call: page 단위로만 재생성해도 컨텍스트의 cookie/storage
        가 누적되면서 BWF SPA가 N틱 후에 "캐시된 빈 상태" 응답으로 락 걸리는
        현상이 재현됨(2026-06-02 tick 7→8에서 active 3→0 고착). 컨텍스트를 매번
        새로 만들어 storage를 완전 격리한다 — 5초쯤 더 걸리지만 락 회피가 훨씬
        중요.
        """
        if self._browser is None:
            raise RuntimeError("Session not entered.")
        url = TOURNAMENT_RESULTS_URL.format(tid=tournament_id, slug=slug, date=date)

        ctx = self._new_ctx()
        page = ctx.new_page()
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=DEFAULT_GOTO_TIMEOUT_MS)
            deadline = time.monotonic() + (LIVE_CARDS_MAX_WAIT_MS / 1000.0)
            while time.monotonic() < deadline:
                seen = page.evaluate(
                    "() => document.querySelectorAll('img[src*=\"live.svg\"]').length"
                )
                if seen > 0:
                    page.wait_for_timeout(500)
                    break
                page.wait_for_timeout(500)

            cards = page.evaluate(EXTRACT_LIVE_CARDS_JS)
            return cards if isinstance(cards, list) else []
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
