"""Probe a single BWF tournament's matches and show parsed rows.

Usage:
    PYTHONPATH=. python batch/scripts/probe_matches.py 5227
    PYTHONPATH=. python batch/scripts/probe_matches.py 5227 --year 2026
"""
import argparse
import json

from batch.jobs.bwf_matches.fetcher import (
    api_session,
    browser_page,
    extract_api_token,
    fetch_draw_matches,
    fetch_tournament_draws,
    fetch_year_calendar,
)
from batch.jobs.bwf_matches.parser import normalize_status, parse_match


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("tournament_id", type=int)
    ap.add_argument("--year", type=int, default=2026)
    args = ap.parse_args()

    with browser_page() as page:
        token = extract_api_token(page)
    print(f"token: {token[:24]}...")
    s = api_session(token)

    calendar = fetch_year_calendar(s, args.year)
    t = next((x for x in calendar if x.get("id") == args.tournament_id), None)
    if not t:
        print(f"tournament {args.tournament_id} not in {args.year} calendar")
        return
    status = normalize_status(t.get("live_status"))
    print(f"\n{t['name']}  id={t['id']}  live_status={t.get('live_status')} -> {status}")

    draws = fetch_tournament_draws(s, args.tournament_id)
    print(f"draws: {[(d.get('text'), d.get('value')) for d in draws]}")

    rows = []
    for d in draws:
        matches = fetch_draw_matches(s, args.tournament_id, str(d.get("value")))
        for m in matches:
            row = parse_match(m, t, d, status)
            if row:
                rows.append(row)
        print(f"  {d.get('text')}: {len(matches)} matches")

    print(f"\ntotal parsed: {len(rows)}")
    if rows:
        sample = {k: v for k, v in rows[0].items() if k != "raw"}
        print("\n--- sample row ---")
        print(json.dumps(sample, ensure_ascii=False, indent=2, default=str))


if __name__ == "__main__":
    main()
