"""Round 2 of entries-endpoint discovery.

Round 1 found `/api/vue-tournament-players` returns 200 but `results: null` with
the simple {tmtId, tmtTab} payload. This script tries richer payloads modeled
after the rankings API (which uses {rankId, catId, publicationId, page,
drawCount, searchKey, pageKey, doubles}) and also re-runs Strategy A snoop with
a richer wait/click protocol on the entries-related URLs the SPA exposes.

Also tries variant tournament URLs we know about:
    /tournament/{id}/{slug}/entries/
    /tournament/{id}/{slug}/players/
    /tournament/{id}/{slug}/                 -- main page; SPA may stay here

Usage:
    PYTHONPATH=. python batch/scripts/probe_tournament_entries_v2.py 5649
"""
import argparse
import json
from pathlib import Path
from typing import Any

import requests

from batch.jobs.bwf_matches.fetcher import (
    api_session,
    browser_page,
    extract_api_token,
    fetch_tournament_draws,
    fetch_year_calendar,
)

OUT_DIR = Path(__file__).resolve().parents[1] / "tests" / "fixtures"
EXTRANET_HOST = "extranet-lv.bwfbadminton.com"
EXTRANET_BASE = f"https://{EXTRANET_HOST}"


def _truncate(value: Any, max_list: int = 3) -> Any:
    if isinstance(value, list):
        head = [_truncate(v, max_list) for v in value[:max_list]]
        if len(value) > max_list:
            head.append(f"<truncated: {len(value) - max_list} more items>")
        return head
    if isinstance(value, dict):
        return {k: _truncate(v, max_list) for k, v in value.items()}
    return value


def make_session(token: str) -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "application/json, text/plain, */*",
            "Content-Type": "application/json;charset=UTF-8",
            "Origin": "https://bwfworldtour.bwfbadminton.com",
            "Referer": "https://bwfworldtour.bwfbadminton.com/",
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
        }
    )
    return s


# Payload variants mirroring patterns seen elsewhere in the BWF API.
def _payload_variants(tmt_id: int, draw_id: str | None) -> list[dict[str, Any]]:
    base_combos = [
        {"tmtId": tmt_id},
        {"tmtId": tmt_id, "tmtTab": "entries"},
        {"tmtId": tmt_id, "tmtTab": "players"},
        {"tmtId": tmt_id, "tmtTab": "draw"},
        # Maybe needs an eventName / discipline filter (MS/WS/MD/WD/XD).
        {"tmtId": tmt_id, "eventName": "MS"},
        {"tmtId": tmt_id, "tmtTab": "entries", "eventName": "MS"},
        # Maybe needs a drawId like vue-tournament-draw-data.
        # filled below if draw_id available.
        # Maybe needs pagination shape like the ranking endpoint.
        {"tmtId": tmt_id, "page": 1, "drawCount": 1, "searchKey": "", "pageKey": "1000"},
        {"tmtId": tmt_id, "tmtTab": "entries", "page": 1, "drawCount": 1, "searchKey": "", "pageKey": "1000"},
        # catId variants (events as numeric ids: MS/WS/MD/WD/XD ≈ 1..5?)
        {"tmtId": tmt_id, "catId": 1},
        {"tmtId": tmt_id, "catId": 1, "tmtTab": "entries"},
    ]
    if draw_id is not None:
        base_combos.extend(
            [
                {"tmtId": tmt_id, "drawId": str(draw_id)},
                {"tmtId": tmt_id, "drawId": str(draw_id), "tmtTab": "entries"},
                {"tmtId": tmt_id, "drawId": str(draw_id), "tmtTab": "draw"},
            ]
        )
    return base_combos


# Endpoints worth re-probing with richer payloads.
ENDPOINTS = [
    "/api/vue-tournament-players",
    "/api/vue-tournament-entries",
    "/api/vue-tournament-entry-list",
    "/api/vue-tournament-data",
    "/api/vue-tournament-summary",
    "/api/vue-tournament-info",
    # Speculative
    "/api/vue-tournament-tab",
    "/api/vue-tournament-tab-data",
    "/api/vue-tournament-entries-data",
    "/api/vue-tournament-players-data",
]


def strategy_b2_richer(
    token: str, tmt_id: int, draw_id: str | None
) -> list[dict[str, Any]]:
    s = make_session(token)
    captured: list[dict[str, Any]] = []
    payloads = _payload_variants(tmt_id, draw_id)
    print(f"\nB2: probing {len(ENDPOINTS)} endpoints x {len(payloads)} payloads = {len(ENDPOINTS) * len(payloads)} requests\n")
    for path in ENDPOINTS:
        for body in payloads:
            try:
                r = s.post(f"{EXTRANET_BASE}{path}", json=body, timeout=15)
            except Exception as e:
                captured.append({"path": path, "body": body, "error": str(e)})
                continue
            ct = r.headers.get("content-type", "")
            preview: Any = None
            try:
                preview = _truncate(r.json())
            except Exception:
                preview = {"_text_head": r.text[:200]}
            has_data = False
            if isinstance(preview, dict):
                if preview.get("results") and not (
                    isinstance(preview["results"], dict)
                    and len(preview["results"]) <= 2
                ):
                    has_data = True
            print(
                f"  {r.status_code}  {path:50s}  body={json.dumps(body)[:90]:90s}"
                + (" <-- data!" if has_data else "")
            )
            captured.append(
                {
                    "path": path,
                    "body": body,
                    "status": r.status_code,
                    "content_type": ct,
                    "body_preview": preview,
                    "has_data": has_data,
                }
            )
    return captured


def strategy_a2_snoop(page: Any, tournament: dict[str, Any]) -> list[dict[str, Any]]:
    """Visit only the entries-related URLs with longer waits + scroll triggers."""
    captured: list[dict[str, Any]] = []

    def on_request(request: Any) -> None:
        if EXTRANET_HOST not in request.url:
            return
        try:
            post_data = request.post_data
        except Exception:
            post_data = None
        captured.append(
            {
                "phase": "request",
                "url": request.url,
                "method": request.method,
                "post_data": post_data,
            }
        )

    def on_response(response: Any) -> None:
        if EXTRANET_HOST not in response.url:
            return
        body_preview: Any = None
        try:
            text = response.body().decode("utf-8", errors="replace")
            try:
                body_preview = _truncate(json.loads(text))
            except Exception:
                body_preview = {"_text_head": text[:200]}
        except Exception as e:
            body_preview = f"<read fail: {e}>"
        captured.append(
            {
                "phase": "response",
                "url": response.url,
                "status": response.status,
                "content_type": response.headers.get("content-type", ""),
                "body_preview": body_preview,
            }
        )

    page.on("request", on_request)
    page.on("response", on_response)

    tid = tournament.get("id")
    slug = tournament.get("name", "").lower().replace(" ", "-")
    # Re-slugify from BWF's own slug if available (vue-tournament-detail had it).
    base = f"https://bwfworldtour.bwfbadminton.com/tournament/{tid}/{slug}"

    for url in [
        f"{base}/entries/",
        f"{base}/players/",
        f"{base}/",
    ]:
        print(f"\n>> [A2] {url}")
        try:
            page.goto(url, wait_until="networkidle", timeout=90_000)
        except Exception as e:
            print(f"   load: {type(e).__name__}: {e}")
        try:
            # Encourage lazy XHR fires.
            page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
            page.wait_for_timeout(3000)
            page.evaluate("window.scrollTo(0, 0)")
            page.wait_for_timeout(2000)
        except Exception:
            pass
        try:
            print(f"   final URL: {page.url}   title: {page.title()[:60]}")
        except Exception:
            pass

    return captured


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("tournament_id", type=int)
    ap.add_argument("--year", type=int, default=2026)
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_file = OUT_DIR / f"tournament_entries_probe_v2_{args.tournament_id}.json"

    snoop: list[dict[str, Any]] = []
    direct: list[dict[str, Any]] = []
    tournament: dict[str, Any] | None = None
    token = ""
    draws: list[dict[str, Any]] = []

    with browser_page() as page:
        token = extract_api_token(page)
        print(f"token: {token[:24]}...")
        s = api_session(token)
        calendar = fetch_year_calendar(s, args.year)
        tournament = next(
            (x for x in calendar if x.get("id") == args.tournament_id), None
        )
        if not tournament:
            print(f"tournament {args.tournament_id} not in {args.year}")
            return
        print(
            f"\ntournament: {tournament['name']}  "
            f"live_status={tournament.get('live_status')}"
        )
        try:
            draws = fetch_tournament_draws(s, args.tournament_id)
            print(f"draws: {[(d.get('text'), d.get('value')) for d in draws]}")
        except Exception as e:
            print(f"draws failed: {e}")

        snoop = strategy_a2_snoop(page, tournament)

    draw_id = str(draws[0].get("value")) if draws else None
    direct = strategy_b2_richer(token, args.tournament_id, draw_id)

    out = {
        "tournament": tournament,
        "draws": draws,
        "strategy_a2_snoop": snoop,
        "strategy_b2_richer": direct,
    }
    out_file.write_text(
        json.dumps(out, ensure_ascii=False, indent=2, default=str),
        encoding="utf-8",
    )
    print(f"\nsaved {out_file}")

    print("\n--- [A2] unique extranet endpoints + payloads ---")
    seen: dict[tuple[str, str, str], int] = {}
    for c in snoop:
        if c.get("phase") != "response" or c.get("status") != 200:
            continue
        url = c["url"].split("?")[0]
        req = next(
            (
                r
                for r in snoop
                if r.get("phase") == "request" and r.get("url") == c["url"]
            ),
            None,
        )
        method = (req or {}).get("method", "?")
        post_data = (req or {}).get("post_data") or ""
        key = (method, url.replace(EXTRANET_BASE, ""), post_data[:80])
        seen[key] = seen.get(key, 0) + 1
    if not seen:
        print("  (none)")
    for (method, path, post), hits in sorted(seen.items(), key=lambda x: -x[1]):
        print(f"  {hits}x  {method:5s} {path}   post={post}")

    print("\n--- [B2] responses with `has_data=True` ---")
    any_hit = False
    for c in direct:
        if c.get("has_data"):
            any_hit = True
            print(f"  ★ {c['path']}  body={json.dumps(c['body'])}")
            print(
                f"    preview: "
                f"{json.dumps(c['body_preview'], default=str)[:400]}"
            )
    if not any_hit:
        print("  (none — entries may live behind a different URL/method)")


if __name__ == "__main__":
    main()
