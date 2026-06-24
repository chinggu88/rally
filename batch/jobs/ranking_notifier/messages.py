CATEGORY_LABEL = {
    "MS": "남자 단식",
    "WS": "여자 단식",
    "MD": "남자 복식",
    "WD": "여자 복식",
    "XD": "혼합 복식",
}


def _direction(rank_change: int) -> tuple[str, str]:
    if rank_change > 0:
        return ("📈", "상승")
    return ("📉", "하락")


def build_message(row: dict) -> tuple[str, str]:
    rank_change = int(row["rank_change"])
    emoji, verb = _direction(rank_change)
    cat = CATEGORY_LABEL.get(row["category"], row["category"])
    change_abs = abs(rank_change)
    title = f"{emoji} 관심선수 랭킹 {verb}"
    body = (
        f"{row['player_name']} ({cat})\n"
        f"세계랭킹 {change_abs}계단 {verb} → 현재 {row['rank']}위"
    )
    return title, body
