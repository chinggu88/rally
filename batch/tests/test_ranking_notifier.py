from batch.jobs.ranking_notifier.detector import expand_member_id
from batch.jobs.ranking_notifier.messages import build_message
from batch.jobs.ranking_notifier.notifier import build_notification_rows


def test_expand_member_id_singles() -> None:
    assert expand_member_id("12345") == [12345]


def test_expand_member_id_doubles() -> None:
    assert expand_member_id("12345-67890") == [12345, 67890]


def test_expand_member_id_with_whitespace() -> None:
    assert expand_member_id(" 12345 - 67890 ") == [12345, 67890]


def test_expand_member_id_invalid_parts_skipped() -> None:
    assert expand_member_id("12345-abc") == [12345]


def test_build_message_singles_up() -> None:
    row = {
        "category": "MS",
        "rank": 5,
        "rank_change": 3,
        "player_name": "LEE Hyun Il",
    }
    title, body = build_message(row)
    assert "상승" in title
    assert "📈" in title
    assert "LEE Hyun Il" in body
    assert "남자 단식" in body
    assert "3계단" in body
    assert "5위" in body


def test_build_message_doubles_down() -> None:
    row = {
        "category": "MD",
        "rank": 12,
        "rank_change": -4,
        "player_name": "KIM Won Ho / SEO Seung Jae",
    }
    title, body = build_message(row)
    assert "하락" in title
    assert "📉" in title
    assert "KIM Won Ho / SEO Seung Jae" in body
    assert "남자 복식" in body
    assert "4계단" in body
    assert "12위" in body


def test_build_notification_rows_carries_dedup_keys() -> None:
    row = {
        "category": "WS",
        "rank": 7,
        "rank_change": 2,
        "member_id": "98765",
        "player_name": "AN Se Young",
    }
    rows = build_notification_rows(
        ["user-a", "user-b"], row, year=2026, week=20
    )
    assert len(rows) == 2
    for r in rows:
        assert r["status"] == "pending"
        assert r["data"]["type"] == "ranking_change"
        assert r["data"]["member_id"] == "98765"
        assert r["data"]["ranking_year"] == "2026"
        assert r["data"]["ranking_week"] == "20"


def test_build_notification_rows_empty_users() -> None:
    row = {
        "category": "MS",
        "rank": 1,
        "rank_change": 1,
        "member_id": "1",
        "player_name": "X",
    }
    assert build_notification_rows([], row, year=2026, week=20) == []
