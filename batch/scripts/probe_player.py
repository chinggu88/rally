"""Probe a single BWF player via the internal API and show the parsed row.

Usage:
    PYTHONPATH=. python batch/scripts/probe_player.py 57945
"""
import json
import sys

from batch.jobs.bwf_players.fetcher import (
    api_session,
    browser_page,
    extract_api_token,
    fetch_player_bio,
    fetch_player_summary,
)
from batch.jobs.bwf_players.parser import parse_player


def main() -> None:
    if len(sys.argv) < 2:
        print("usage: probe_player.py <player_id>", file=sys.stderr)
        sys.exit(2)

    player_id = int(sys.argv[1])
    detail_url = f"https://bwfbadminton.com/player/{player_id}/"

    with browser_page() as page:
        token = extract_api_token(page)
    print(f"token: {token[:24]}...")

    s = api_session(token)
    summary = fetch_player_summary(s, player_id)
    bio = fetch_player_bio(s, player_id)
    row = parse_player(summary, bio, player_id, detail_url)

    printable = {k: v for k, v in row.items() if k != "raw"}
    print(json.dumps(printable, ensure_ascii=False, indent=2, default=str))

    print("\n--- non-null fields ---")
    for k, v in printable.items():
        if v not in (None, "", {}, []):
            print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
