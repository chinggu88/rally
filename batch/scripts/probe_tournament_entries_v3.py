"""Round 3 of entries-endpoint discovery.

v2 returned an empty strategy_a2_snoop because:
  (a) the request/response handlers filtered for EXTRANET_HOST only — calls to
      other hosts (CMS, alt API subdomains) were silently dropped
  (b) page.goto() never clicked the "Players" / event (MS/WS/...) tabs, so any
      XHR that the SPA fires only on tab interaction was never triggered
  (c) settle time (3+2s) was too short for Cloudflare challenge resolution and
      lazy XHR fires

v3 fixes all three:
  - Capture every request/response, excluding only static assets and known
    analytics/CDN noise hosts
  - After goto, attempt to click "Players"/"Entries" tab and each event tab
    (MS/WS/MD/WD/XD) to surface per-event XHRs
  - Longer settle window (default 8000 ms, overridable with --wait)
  - Store full response bodies (200 KB cap) and scan for "smoking gun" needles
    like "Naraoka" / "seed" / "player_name" so the operator can spot the real
    entries endpoint immediately

Usage:
    PYTHONPATH=. python batch/scripts/probe_tournament_entries_v3.py 5528 --year 2026

Options:
    --no-brute            Skip Strategy B (brute-force POST sweep)
    --needle Naraoka      Comma-separated smoking-gun keywords (default:
                          "Naraoka,seed,player_name")
    --wait 10000          Per-page settle ms after networkidle (default 8000)
"""
import argparse
import json
import re
import urllib.parse
from pathlib import Path
from typing import Any, Callable

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
DEFAULT_NEEDLES = ["Naraoka", "seed", "player_name"]
DEFAULT_WAIT_MS = 8000
MAX_BODY_BYTES = 200_000

# ---------------------------------------------------------------------------
# Filters: skip static assets + analytics/CDN noise so we keep only API-ish calls
# ---------------------------------------------------------------------------
ASSET_EXT_RE = re.compile(
    r"\.(?:js|mjs|css|map|png|jpe?g|gif|webp|svg|ico|woff2?|ttf|eot|"
    r"mp4|webm|avif|json\.map)(?:\?|$)",
    re.IGNORECASE,
)
NOISE_HOST_RE = re.compile(
    r"(?:google-analytics|googletagmanager|doubleclick|googleadservices|"
    r"google\.com/recaptcha|gstatic|fonts\.googleapis|"
    r"facebook|connect\.facebook|hotjar|segment|sentry|cloudflareinsights|"
    r"clarity\.ms|youtube|cookielaw|onetrust|newrelic|datadoghq|"
    r"amplitude|mixpanel|tiktok|twitter|x\.com/i)",
    re.IGNORECASE,
)


def is_interesting(url: str, content_type: str | None = None) -> bool:
    """Keep API-ish calls; drop static assets + analytics."""
    if ASSET_EXT_RE.search(url):
        return False
    if NOISE_HOST_RE.search(url):
        return False
    # Be permissive about content-type: BWF's extranet returns
    # `text/html; charset=UTF-8` for JSON-bodied API responses.
    return True


def _truncate(value: Any, max_list: int = 3) -> Any:
    """Used only for summary printing — fixture stores full bodies."""
    if isinstance(value, list):
        head = [_truncate(v, max_list) for v in value[:max_list]]
        if len(value) > max_list:
            head.append(f"<truncated: {len(value) - max_list} more items>")
        return head
    if isinstance(value, dict):
        return {k: _truncate(v, max_list) for k, v in value.items()}
    return value


# ---------------------------------------------------------------------------
# Strategy A3: browser snoop with all-domain capture + tab interaction
# ---------------------------------------------------------------------------
PLAYERS_TAB_SELECTORS = [
    "a[href*='/players/']",
    "a[href*='/entries/']",
    "[role='tab']:has-text('Players')",
    "[role='tab']:has-text('Entries')",
    ".nav-tabs a:has-text('Players')",
    ".nav-tabs a:has-text('Entries')",
    "button:has-text('Players')",
    "button:has-text('Entries')",
    "text=/^\\s*Players\\s*$/i",
    "text=/^\\s*Entries\\s*$/i",
]

EVENT_TAB_SELECTORS = [
    # Plain text (case-sensitive — discipline codes are uppercase)
    "text=/^\\s*MS\\s*$/", "text=/^\\s*WS\\s*$/",
    "text=/^\\s*MD\\s*$/", "text=/^\\s*WD\\s*$/",
    "text=/^\\s*XD\\s*$/",
    # Data-attribute conventions
    "[data-event='MS']", "[data-event='WS']",
    "[data-event='MD']", "[data-event='WD']", "[data-event='XD']",
    # Verbose discipline names
    "button:has-text(\"Men's Singles\")",
    "button:has-text(\"Women's Singles\")",
    "button:has-text(\"Men's Doubles\")",
    "button:has-text(\"Women's Doubles\")",
    "button:has-text(\"Mixed Doubles\")",
]

INTERESTING_HEADER_KEYS = {
    "authorization", "content-type", "x-requested-with", "origin", "referer",
}


def make_capture(
    needles: list[str],
) -> tuple[list[dict[str, Any]], Callable[[Any], None], Callable[[Any], None]]:
    captured: list[dict[str, Any]] = []
    needles_lower = [n.lower() for n in needles]

    def on_request(req: Any) -> None:
        try:
            url = req.url
        except Exception:
            return
        if not is_interesting(url):
            return
        u = urllib.parse.urlsplit(url)
        try:
            post_data = req.post_data
        except Exception:
            post_data = None
        try:
            headers = {
                k: v
                for k, v in req.headers.items()
                if k.lower() in INTERESTING_HEADER_KEYS
            }
        except Exception:
            headers = {}
        captured.append(
            {
                "phase": "request",
                "host": u.netloc,
                "path": u.path,
                "query": u.query,
                "method": req.method,
                "post_data": post_data,
                "headers": headers,
            }
        )

    def on_response(resp: Any) -> None:
        try:
            url = resp.url
        except Exception:
            return
        try:
            ct = resp.headers.get("content-type", "") if resp.headers else ""
        except Exception:
            ct = ""
        if not is_interesting(url, ct):
            return
        u = urllib.parse.urlsplit(url)
        entry: dict[str, Any] = {
            "phase": "response",
            "host": u.netloc,
            "path": u.path,
            "query": u.query,
            "status": resp.status,
            "content_type": ct,
        }
        try:
            raw = resp.body()
            if raw is None:
                raw = b""
            if len(raw) <= MAX_BODY_BYTES:
                txt = raw.decode("utf-8", errors="replace")
                try:
                    entry["body_json"] = json.loads(txt)
                except Exception:
                    entry["body_text_head"] = txt[:500]
                lower = txt.lower()
                hits = [
                    needles[i]
                    for i, n in enumerate(needles_lower)
                    if n in lower
                ]
                if hits:
                    entry["needle_hits"] = hits
            else:
                entry["body_size"] = len(raw)
                entry["body_text_head"] = raw[:500].decode("utf-8", "replace")
        except Exception as e:
            entry["body_error"] = str(e)
        captured.append(entry)

    return captured, on_request, on_response


def _try_click_first_visible(page: Any, selectors: list[str], label: str) -> None:
    for sel in selectors:
        try:
            loc = page.locator(sel).first
            if loc.count() and loc.is_visible():
                print(f"   click {label}: {sel}")
                loc.click(timeout=3000)
                page.wait_for_timeout(3000)
                return
        except Exception:
            continue


def _try_click_each_visible(page: Any, selectors: list[str], label: str) -> None:
    """For event tabs: click each one we find, waiting between clicks."""
    for sel in selectors:
        try:
            loc = page.locator(sel)
            n = loc.count()
            for i in range(min(n, 5)):
                item = loc.nth(i)
                try:
                    if item.is_visible():
                        print(f"   click {label}[{i}]: {sel}")
                        item.click(timeout=2000)
                        page.wait_for_timeout(2500)
                except Exception:
                    continue
        except Exception:
            continue


def strategy_a3_snoop(
    page: Any,
    tournament: dict[str, Any],
    settle_ms: int,
    needles: list[str],
) -> list[dict[str, Any]]:
    captured, on_req, on_resp = make_capture(needles)
    page.on("request", on_req)
    page.on("response", on_resp)

    tid = tournament.get("id")
    slug = tournament.get("name", "").lower().replace(" ", "-")
    base = f"https://bwfworldtour.bwfbadminton.com/tournament/{tid}/{slug}"

    for url in [f"{base}/players/", f"{base}/entries/", f"{base}/"]:
        print(f"\n>> [A3] goto {url}")
        try:
            page.goto(url, wait_until="domcontentloaded", timeout=90_000)
        except Exception as e:
            print(f"   goto: {type(e).__name__}: {e}")
        try:
            page.wait_for_load_state("networkidle", timeout=30_000)
        except Exception:
            pass
        page.wait_for_timeout(settle_ms)

        # SPA may keep us on the main page; click into Players/Entries tab.
        _try_click_first_visible(page, PLAYERS_TAB_SELECTORS, "players-tab")

        # Then walk each discipline tab to trigger per-event XHRs.
        _try_click_each_visible(page, EVENT_TAB_SELECTORS, "event-tab")

        # Scroll wiggle for lazy fires.
        try:
            page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
            page.wait_for_timeout(2000)
            page.evaluate("window.scrollTo(0, 0)")
            page.wait_for_timeout(1500)
        except Exception:
            pass

        try:
            print(
                f"   final URL: {page.url}   title: {page.title()[:60]}"
            )
        except Exception:
            pass

    return captured


# ---------------------------------------------------------------------------
# Strategy B3 (optional): brute-force POST sweep, kept from v2 for parity
# ---------------------------------------------------------------------------
ENDPOINTS_B3 = [
    "/api/vue-tournament-players",
    "/api/vue-tournament-entries",
    "/api/vue-tournament-entry-list",
    "/api/vue-tournament-data",
    "/api/vue-tournament-summary",
    "/api/vue-tournament-info",
    "/api/vue-tournament-tab",
    "/api/vue-tournament-tab-data",
    "/api/vue-tournament-entries-data",
    "/api/vue-tournament-players-data",
]


def _payload_variants_b3(
    tmt_id: int, draw_id: str | None
) -> list[dict[str, Any]]:
    base = [
        {"tmtId": tmt_id},
        {"tmtId": tmt_id, "tmtTab": "entries"},
        {"tmtId": tmt_id, "tmtTab": "players"},
        {"tmtId": tmt_id, "tmtTab": "draw"},
        {"tmtId": tmt_id, "eventName": "MS"},
        {"tmtId": tmt_id, "tmtTab": "entries", "eventName": "MS"},
        {
            "tmtId": tmt_id, "page": 1, "drawCount": 1,
            "searchKey": "", "pageKey": "1000",
        },
        {
            "tmtId": tmt_id, "tmtTab": "entries", "page": 1,
            "drawCount": 1, "searchKey": "", "pageKey": "1000",
        },
        {"tmtId": tmt_id, "catId": 1},
        {"tmtId": tmt_id, "catId": 1, "tmtTab": "entries"},
    ]
    if draw_id is not None:
        base.extend(
            [
                {"tmtId": tmt_id, "drawId": str(draw_id)},
                {"tmtId": tmt_id, "drawId": str(draw_id), "tmtTab": "entries"},
                {"tmtId": tmt_id, "drawId": str(draw_id), "tmtTab": "draw"},
            ]
        )
    return base


def _make_brute_session(token: str) -> requests.Session:
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


def strategy_b3_richer(
    token: str,
    tmt_id: int,
    draw_id: str | None,
    needles: list[str],
) -> list[dict[str, Any]]:
    s = _make_brute_session(token)
    needles_lower = [n.lower() for n in needles]
    captured: list[dict[str, Any]] = []
    payloads = _payload_variants_b3(tmt_id, draw_id)
    print(
        f"\nB3: probing {len(ENDPOINTS_B3)} endpoints x {len(payloads)} "
        f"payloads = {len(ENDPOINTS_B3) * len(payloads)} requests\n"
    )
    for path in ENDPOINTS_B3:
        for body in payloads:
            try:
                r = s.post(f"{EXTRANET_BASE}{path}", json=body, timeout=15)
            except Exception as e:
                captured.append({"path": path, "body": body, "error": str(e)})
                continue
            ct = r.headers.get("content-type", "")
            entry: dict[str, Any] = {
                "path": path,
                "body": body,
                "status": r.status_code,
                "content_type": ct,
            }
            txt = r.text or ""
            try:
                entry["body_preview"] = _truncate(json.loads(txt))
            except Exception:
                entry["body_text_head"] = txt[:200]
            lower = txt.lower()
            hits = [
                needles[i] for i, n in enumerate(needles_lower) if n in lower
            ]
            if hits:
                entry["needle_hits"] = hits
            print(
                f"  {r.status_code}  {path:50s}  "
                f"body={json.dumps(body)[:90]:90s}"
                + (f"  <-- {','.join(hits)}" if hits else "")
            )
            captured.append(entry)
    return captured


# ---------------------------------------------------------------------------
# Summary: group captured A3 calls + highlight smoking guns
# ---------------------------------------------------------------------------
def summarize(
    captured: list[dict[str, Any]],
) -> dict[str, Any]:
    by_key: dict[tuple[str, str, str], dict[str, Any]] = {}
    request_by_url: dict[str, dict[str, Any]] = {}
    for c in captured:
        if c.get("phase") == "request":
            request_by_url.setdefault(
                f"{c['method']} {c['host']}{c['path']}?{c['query']}", c
            )

    for c in captured:
        if c.get("phase") != "response":
            continue
        # Find matching request for method/post_data.
        method = "GET"
        post_sample = ""
        for k, req in request_by_url.items():
            if (
                req["host"] == c["host"]
                and req["path"] == c["path"]
                and req["query"] == c["query"]
            ):
                method = req.get("method", "GET")
                post_sample = (req.get("post_data") or "")[:200]
                break
        key = (c["host"], c["path"], method)
        slot = by_key.setdefault(
            key,
            {
                "host": c["host"],
                "path": c["path"],
                "method": method,
                "hits": 0,
                "sample_post": post_sample,
                "sample_status": c.get("status"),
                "response_keys": None,
                "needle_hits": [],
            },
        )
        slot["hits"] += 1
        if slot["response_keys"] is None and isinstance(
            c.get("body_json"), dict
        ):
            slot["response_keys"] = sorted(list(c["body_json"].keys()))[:20]
        for h in c.get("needle_hits", []):
            if h not in slot["needle_hits"]:
                slot["needle_hits"].append(h)

    unique = sorted(
        by_key.values(), key=lambda s: (-len(s["needle_hits"]), -s["hits"])
    )
    smoking_guns = [s for s in unique if s["needle_hits"]]
    return {"unique_endpoints": unique, "smoking_guns": smoking_guns}


def print_summary(summary: dict[str, Any]) -> None:
    print("\n--- [A3] unique endpoints (host + path + method) ---")
    if not summary["unique_endpoints"]:
        print("  (none captured)")
    for s in summary["unique_endpoints"]:
        star = " ★" if s["needle_hits"] else "  "
        print(
            f" {star} {s['hits']:3d}x  {s['method']:5s} "
            f"{s['host']}{s['path']}"
            + (f"   needle={','.join(s['needle_hits'])}" if s["needle_hits"] else "")
        )
        if s["sample_post"]:
            print(f"        post: {s['sample_post']}")
        if s["response_keys"]:
            print(f"        keys: {s['response_keys']}")

    print("\n--- [A3] smoking guns ---")
    if not summary["smoking_guns"]:
        print("  (none — try --wait 15000 or expand --needle)")
    for s in summary["smoking_guns"]:
        print(
            f"  ★ {s['method']} https://{s['host']}{s['path']}  "
            f"hits={s['hits']}  needle={','.join(s['needle_hits'])}"
        )


# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("tournament_id", type=int)
    ap.add_argument("--year", type=int, default=2026)
    ap.add_argument(
        "--no-brute", action="store_true", help="Skip Strategy B3 brute sweep"
    )
    ap.add_argument(
        "--needle",
        default=",".join(DEFAULT_NEEDLES),
        help="Comma-separated smoking-gun keywords (case-insensitive)",
    )
    ap.add_argument(
        "--wait",
        type=int,
        default=DEFAULT_WAIT_MS,
        help="Per-page settle ms after networkidle",
    )
    args = ap.parse_args()

    needles = [n.strip() for n in args.needle.split(",") if n.strip()]
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_file = OUT_DIR / f"tournament_entries_probe_v3_{args.tournament_id}.json"

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

        snoop = strategy_a3_snoop(page, tournament, args.wait, needles)

    summary = summarize(snoop)

    if not args.no_brute:
        draw_id = str(draws[0].get("value")) if draws else None
        direct = strategy_b3_richer(token, args.tournament_id, draw_id, needles)

    out = {
        "tournament": tournament,
        "draws": draws,
        "args": {"needles": needles, "settle_ms": args.wait},
        "strategy_a3_snoop": snoop,
        "summary": summary,
        "strategy_b3_richer": direct,
    }
    out_file.write_text(
        json.dumps(out, ensure_ascii=False, indent=2, default=str),
        encoding="utf-8",
    )
    print(f"\nsaved {out_file}")

    print_summary(summary)

    if not args.no_brute:
        print("\n--- [B3] responses with needle hits ---")
        any_hit = False
        for c in direct:
            if c.get("needle_hits"):
                any_hit = True
                print(
                    f"  ★ {c['path']}  body={json.dumps(c['body'])}  "
                    f"needle={','.join(c['needle_hits'])}"
                )
        if not any_hit:
            print("  (none)")


if __name__ == "__main__":
    main()
