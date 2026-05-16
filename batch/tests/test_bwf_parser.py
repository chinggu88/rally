from pathlib import Path

import pytest

from batch.jobs.bwf_rankings.parser import parse_rankings_table

FIXTURE_DIR = Path(__file__).parent / "fixtures"
MS_FIXTURE = FIXTURE_DIR / "bwf_ms_sample.html"


@pytest.mark.skipif(not MS_FIXTURE.exists(), reason="fixture not captured yet")
def test_parse_ms_rankings() -> None:
    html = MS_FIXTURE.read_text(encoding="utf-8")
    rows = parse_rankings_table(html, category="MS", year=2026, week=20)

    assert len(rows) > 0

    first = rows[0]
    assert first["category"] == "MS"
    assert first["rank"] >= 1
    assert first["player_name"]
    assert first["member_id"]
    assert isinstance(first["points"], float)
    assert first["points"] > 0
    assert first["ranking_year"] == 2026
    assert first["ranking_week"] == 20

    ranks = [r["rank"] for r in rows]
    assert ranks == sorted(ranks), "ranks should be ascending"


def test_parse_empty_table_raises() -> None:
    with pytest.raises(ValueError):
        parse_rankings_table("<html><body>no table</body></html>", "MS", 2026, 20)
