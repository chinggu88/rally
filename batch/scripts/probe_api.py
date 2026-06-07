"""Probe API: dump first page of MS ranking JSON to inspect field shape."""
import json
from pathlib import Path

from batch.jobs.bwf_rankings.fetcher import (
    fetch_category_page,
    get_latest_publication,
)

OUT = Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "api_ms_page1.json"


def main() -> None:
    pub = get_latest_publication()
    print(f"latest publication: {json.dumps(pub, ensure_ascii=False)}")

    data = fetch_category_page(
        cat_id=6,
        publication_id=pub["id"],
        page_key=1000,
        page=1,
        draw_count=1,
    )
    OUT.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nsaved to {OUT}")

    results = data.get("results", {})
    print(f"\npagination: current={results.get('current_page')} last={results.get('last_page')} total={results.get('total')} per_page={results.get('per_page')}")
    rows = results.get("data") or []
    if rows:
        print("\nfirst row keys:", list(rows[0].keys()))
        print("\nfirst row:")
        print(json.dumps(rows[0], ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
