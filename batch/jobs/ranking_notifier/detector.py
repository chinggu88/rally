from typing import Any


def expand_member_id(member_id: str) -> list[int]:
    """단식 "12345" → [12345], 복식 "12345-67890" → [12345, 67890]."""
    out: list[int] = []
    for part in member_id.split("-"):
        part = part.strip()
        if not part:
            continue
        try:
            out.append(int(part))
        except ValueError:
            continue
    return out


def fetch_changed_rankings(supabase: Any, year: int, week: int) -> list[dict]:
    res = (
        supabase.table("bwf_rankings")
        .select("category, rank, rank_change, member_id, player_name")
        .eq("ranking_year", year)
        .eq("ranking_week", week)
        .neq("rank_change", 0)
        .not_.is_("rank_change", "null")
        .execute()
    )
    return res.data or []


def fetch_interested_users(supabase: Any, player_ids: list[int]) -> list[str]:
    """player_ids 중 하나라도 관심등록한 user_id 목록 (알림 활성 유저만)."""
    if not player_ids:
        return []
    res = (
        supabase.table("favorite_players")
        .select("user_id, profiles!inner(notifications_enabled)")
        .in_("player_id", player_ids)
        .eq("profiles.notifications_enabled", True)
        .execute()
    )
    rows = res.data or []
    return list({r["user_id"] for r in rows})


def fetch_already_notified_user_ids(
    supabase: Any, member_id: str, year: int, week: int
) -> set[str]:
    """같은 주(year/week) + 같은 member_id 로 이미 알림 row가 있는 user_id 집합."""
    res = (
        supabase.table("notifications")
        .select("user_id")
        .eq("data->>type", "ranking_change")
        .eq("data->>member_id", member_id)
        .eq("data->>ranking_year", str(year))
        .eq("data->>ranking_week", str(week))
        .execute()
    )
    rows = res.data or []
    return {r["user_id"] for r in rows}
