def build_summary_message() -> tuple[str, str]:
    """유저당 1건 요약 알림 본문. 상세는 앱 알림 화면에서 확인."""
    title = "📊 관심선수 랭킹 변동"
    body = "관심선수의 세계랭킹이 변동했어요. 눌러서 확인하세요."
    return title, body
