"""One-shot probe: load /rankings/ and dump key selectors + current URL + first 3000 chars of HTML."""
from pathlib import Path

from batch.jobs.bwf_rankings.fetcher import ENTRY_URL, browser_page

OUT = Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "entry_dump.html"


def main() -> None:
    with browser_page() as page:
        page.goto(ENTRY_URL, wait_until="domcontentloaded", timeout=60_000)
        page.wait_for_timeout(3000)  # let Cloudflare challenge resolve if any
        print(f"final URL: {page.url}")
        print(f"title: {page.title()}")

        for selector in [
            "select#ranking-week",
            "select[id*='week']",
            "select[id*='ranking']",
            "select",
            "table.tblRankingLanding",
            "a[href*='/rankings/2/']",
            ".cf-error-code",
        ]:
            count = page.locator(selector).count()
            print(f"  {selector}: {count} matches")

        html = page.content()
        OUT.write_text(html, encoding="utf-8")
        print(f"\nsaved {len(html)} chars to {OUT}")
        print("\n--- first 1500 chars ---")
        print(html[:1500])


if __name__ == "__main__":
    main()
