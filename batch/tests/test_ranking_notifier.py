from batch.jobs.ranking_notifier.detector import expand_member_id
from batch.jobs.ranking_notifier.messages import build_summary_message
from batch.jobs.ranking_notifier.notifier import build_summary_rows


def test_expand_member_id_singles() -> None:
    assert expand_member_id("12345") == [12345]


def test_expand_member_id_doubles() -> None:
    assert expand_member_id("12345-67890") == [12345, 67890]


def test_expand_member_id_with_whitespace() -> None:
    assert expand_member_id(" 12345 - 67890 ") == [12345, 67890]


def test_expand_member_id_invalid_parts_skipped() -> None:
    assert expand_member_id("12345-abc") == [12345]


def test_build_summary_message_is_generic() -> None:
    title, body = build_summary_message()
    assert "관심선수" in title
    assert "눌러서 확인" in body


def _change(member_id: str, name: str, cat: str, rank: int, rc: int) -> dict:
    return {
        "member_id": member_id,
        "player_name": name,
        "category": cat,
        "rank": rank,
        "rank_change": rc,
    }


def test_build_summary_rows_one_row_per_user_with_changes() -> None:
    user_changes = {
        "user-a": [
            _change("98765", "AN Se Young", "WS", 7, 2),
            _change("54321-11111", "KIM / SEO", "MD", 12, -4),
        ],
        "user-b": [_change("98765", "AN Se Young", "WS", 7, 2)],
    }
    rows = build_summary_rows(user_changes, year=2026, week=20)
    assert len(rows) == 2

    by_user = {r["user_id"]: r for r in rows}
    a = by_user["user-a"]
    assert a["status"] == "pending"
    assert a["data"]["type"] == "ranking_change"
    assert a["data"]["ranking_year"] == "2026"
    assert a["data"]["ranking_week"] == "20"
    assert a["data"]["count"] == 2
    assert len(a["data"]["changes"]) == 2
    assert a["data"]["changes"][0]["player_name"] == "AN Se Young"

    assert by_user["user-b"]["data"]["count"] == 1


def test_build_summary_rows_skips_users_without_changes() -> None:
    rows = build_summary_rows({"user-a": []}, year=2026, week=20)
    assert rows == []


def test_build_summary_rows_empty() -> None:
    assert build_summary_rows({}, year=2026, week=20) == []
