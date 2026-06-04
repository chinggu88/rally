"""BWF live tournaments worker — 10초 주기 페이지 reload + 응답 캡처.

BWF 운영이 인증 모델을 바꾸면서(Bearer 토큰 제거, Cloudflare JA3 검사 강화)
HTTP 클라이언트 직접 호출이 모두 403을 받는다. 유일하게 통과하는 경로는
SPA가 자기 컨텍스트에서 호출한 응답을 가로채는 것이다.

설계:
  - LiveCalendarSession을 워커 시작 시 한 번 열고 종료 시 닫는다
  - 매 틱: page.reload (정확히는 goto) → SPA가 vue-current-live를 자동 호출 →
    page.on('response')로 JSON 가로채기 → upsert
  - 응답이 빈 results이면(라이브 대회 0개) ended_at sweep도 스킵 (전부 종료
    처리되는 사고 방지). 단, "정상적으로 빈" 케이스와 "캡처 실패"를 구분하기
    위해 payload=None이면 스킵, payload={"results":[]}는 sweep 수행.

CLI:
  python -m batch.jobs.bwf_live_matches.main               # 상주
  python -m batch.jobs.bwf_live_matches.main --once        # 한 틱
  python -m batch.jobs.bwf_live_matches.main --once --dry-run
"""
from __future__ import annotations

import argparse
import json
import os
import signal
import sys
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from batch.jobs.bwf_live_matches.fetcher import LiveCalendarSession
from batch.jobs.bwf_live_matches.parser import (
    live_tournament_routing_info,
    parse_live_match_cards,
    parse_live_tournaments,
)
from batch.jobs.bwf_live_matches.upserter import (
    mark_ended,
    upsert_live_matches,
    upsert_parents,
)
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "bwf_live_matches"

POLL_INTERVAL_SECONDS = 10
HEARTBEAT_INTERVAL_MINUTES = 60
# 캘린더(vue-current-live)는 빠르게 바뀌지 않으므로 N분만 캐시한 뒤 재호출.
# 매 틱마다 호출하면 BWF SPA가 충분히 빨리 응답하지 못해 None을 자주 반환한다.
CALENDAR_REFRESH_SECONDS = 300

BATCH_ENV = Path(__file__).resolve().parents[2] / ".env"


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.isoformat()


# ---- batch_logs ------------------------------------------------------------


def _start_log(supabase: Any, metadata: dict[str, Any]) -> int:
    res = (
        supabase.table("batch_logs")
        .insert({"job": JOB_NAME, "status": "started", "metadata": metadata})
        .execute()
    )
    return res.data[0]["id"]


def _update_log(
    supabase: Any,
    log_id: int,
    status: str,
    rows_written: int,
    metadata: dict[str, Any] | None = None,
    error: str | None = None,
    finish: bool = False,
) -> None:
    payload: dict[str, Any] = {"status": status, "rows_written": rows_written}
    if finish:
        payload["finished_at"] = _iso(_now())
    if metadata is not None:
        payload["metadata"] = metadata
    if error is not None:
        payload["error"] = error
    supabase.table("batch_logs").update(payload).eq("id", log_id).execute()


# ---- Worker state ---------------------------------------------------------


class WorkerState:
    def __init__(self) -> None:
        self.ticks: int = 0
        self.last_heartbeat: datetime | None = None
        self.total_upserted: int = 0
        self.total_ended: int = 0
        self.last_active_ids: list[int] = []
        self.last_capture_ok: datetime | None = None
        self.stop_requested: bool = False
        # 캘린더 캐시 — vue-current-live는 5분 주기로만 갱신.
        self.cached_parents: list[dict[str, Any]] = []
        self.cached_routes: list[dict[str, Any]] = []
        self.calendar_cached_at: datetime | None = None


def _heartbeat_due(state: WorkerState) -> bool:
    if state.last_heartbeat is None:
        return False
    return _now() - state.last_heartbeat > timedelta(
        minutes=HEARTBEAT_INTERVAL_MINUTES
    )


def _heartbeat_meta(state: WorkerState) -> dict[str, Any]:
    return {
        "ticks": state.ticks,
        "total_upserted": state.total_upserted,
        "total_ended": state.total_ended,
        "last_active_count": len(state.last_active_ids),
        "last_capture_ok": (
            _iso(state.last_capture_ok) if state.last_capture_ok else None
        ),
    }


# ---- One tick -------------------------------------------------------------


def _today_url_segment() -> str:
    """results/{YYYY-MM-DD} 경로용 — BWF SPA는 로컬/대회 시간 기준이 아닌 단순
    YYYY-MM-DD 슬러그를 받는다. UTC로 통일하면 KST 자정~9시 사이엔 어제로 갈
    수 있어 위험. 대신 'tournament 일정' 안에서 가장 가까운 오늘로 보정도
    가능하지만, 우선 UTC 사용 (BWF 토너먼트는 대부분 UTC+0~+8). 추후 보정.
    """
    return _now().strftime("%Y-%m-%d")


def _calendar_stale(state: WorkerState) -> bool:
    if state.calendar_cached_at is None:
        return True
    return (_now() - state.calendar_cached_at).total_seconds() > CALENDAR_REFRESH_SECONDS


def _run_one_tick(
    session: LiveCalendarSession,
    supabase: Any,
    log,
    state: WorkerState,
    dry_run: bool,
    year: int,
) -> None:
    # 1) 캘린더 캐시 갱신 (5분 주기). 실패하면 이전 캐시로 결과 polling 계속.
    if _calendar_stale(state):
        payload = session.fetch_current_live()
        if payload is not None:
            state.cached_parents = parse_live_tournaments(payload, year)
            state.cached_routes = live_tournament_routing_info(payload)
            state.calendar_cached_at = _now()
            state.last_capture_ok = _now()
            log.info(
                f"calendar refreshed: {len(state.cached_routes)} live tournament(s)"
            )
        elif state.calendar_cached_at is None:
            log.warning("initial vue-current-live capture failed; will retry next tick")
            return
        else:
            log.warning(
                "vue-current-live refresh failed; reusing previous cache "
                f"(age={(_now() - state.calendar_cached_at).total_seconds():.0f}s)"
            )

    parents = state.cached_parents
    routes = state.cached_routes
    if not routes:
        log.info("no live tournaments")
        return

    # 각 라이브 대회의 results/{today} 페이지에서 라이브 카드 수집
    # polled_tournament_ids = results 페이지 navigation까지 예외 없이 통과한 대회.
    # 카드 0개여도 "조회는 성공"으로 본다 — mark_ended는 이 경계 안에서만 sweep
    # 한다(SPA 캐시 락/네트워크 실패 케이스의 폭주 방지).
    today = _today_url_segment()
    all_matches: list[dict[str, Any]] = []
    per_tournament: list[tuple[str, int, int]] = []  # (name, tid, card_count)
    polled_tournament_ids: list[int] = []
    for route in routes:
        tid = route["tournament_id"]
        try:
            cards = session.fetch_live_match_cards(
                tournament_id=tid, slug=route["slug"], date=today
            )
        except Exception as e:
            log.warning(
                f"results page navigation failed tid={tid}: {type(e).__name__}: {e}"
            )
            continue
        polled_tournament_ids.append(tid)
        matches = parse_live_match_cards(cards, route)
        all_matches.extend(matches)
        per_tournament.append((route["name"], tid, len(matches)))

    active_match_ids = [m["id"] for m in all_matches]
    state.last_active_ids = active_match_ids

    if dry_run:
        sample = {
            "parents": [{k: v for k, v in p.items() if k != "raw"} for p in parents],
            "matches_preview": [
                {k: v for k, v in m.items() if k != "raw"}
                for m in all_matches[:3]
            ],
            "per_tournament": per_tournament,
        }
        print(json.dumps(sample, ensure_ascii=False, indent=2, default=str))
        log.info(
            f"dry-run — would upsert {len(parents)} parent tournament(s) "
            f"and {len(all_matches)} live match(es)"
        )
        return

    upsert_parents(supabase, parents)
    written = upsert_live_matches(supabase, all_matches)
    state.total_upserted += written

    # results 페이지 navigation까지 성공한 대회 경계 안에서만 sweep한다.
    # - polled에 있고 active_ids에 없는 row → 그 대회는 조회됐는데 매치가 더
    #   이상 라이브가 아니라는 뜻 → 종료 처리.
    # - polled에 없는 대회(전부 navigation 실패) → 안전책으로 sweep 스킵.
    if polled_tournament_ids:
        ended = mark_ended(
            supabase, active_match_ids, log,
            polled_tournament_ids=polled_tournament_ids,
        )
        state.total_ended += ended
    else:
        ended = 0
        log.info("skipping mark_ended: no tournament results page polled this tick")
    log.info(
        f"tick {state.ticks}: parents={len(parents)} matches_upserted={written} "
        f"active_matches={len(active_match_ids)} newly_ended={ended} "
        f"polled_tournaments={len(polled_tournament_ids)} "
        f"by_tournament={per_tournament}"
    )


# ---- Signal handlers ------------------------------------------------------


def _install_signal_handlers(state: WorkerState, log) -> None:
    """첫 시그널은 graceful (다음 시그널 체크 지점에서 종료), 두 번째 이상은 즉시
    프로세스 종료. Playwright sync API 콜이 길어(20초+) 첫 신호가 들어와도 한
    틱 끝까지 기다려야 하는 답답함을 우회한다.
    """
    signal_count = {"n": 0}

    def _handle(signum, _frame):
        signal_count["n"] += 1
        if signal_count["n"] == 1:
            log.info(
                f"Signal {signum} received — stopping after current tick "
                f"(press Ctrl+C again to force quit)"
            )
            state.stop_requested = True
        else:
            log.warning(
                f"Signal {signum} received again ({signal_count['n']}x) — force quit"
            )
            # SIGINT 종료 코드 관례 (130 = 128 + SIGINT(2))
            os._exit(130)

    signal.signal(signal.SIGINT, _handle)
    signal.signal(signal.SIGTERM, _handle)


# ---- Entry ---------------------------------------------------------------


def run(
    year: int | None = None,
    dry_run: bool = False,
    once: bool = False,
    headless: bool = True,
) -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    year = year or _now().year
    log.info(
        f"Starting {JOB_NAME} "
        f"(year={year}, dry_run={dry_run}, once={once}, headless={headless})"
    )

    supabase = None if dry_run else get_client()
    state = WorkerState()
    log_id: int | None = None

    if supabase is not None and not once:
        log_id = _start_log(
            supabase,
            metadata={
                "poll_interval_seconds": POLL_INTERVAL_SECONDS,
                "year": year,
            },
        )
        _install_signal_handlers(state, log)

    try:
        with LiveCalendarSession(year=year, headless=headless) as session:
            while True:
                tick_start = time.monotonic()
                state.ticks += 1
                try:
                    _run_one_tick(session, supabase, log, state, dry_run, year)
                except Exception as e:
                    log.exception(f"Tick {state.ticks} crashed: {e}")

                if (
                    supabase is not None
                    and log_id is not None
                    and _heartbeat_due(state)
                ):
                    try:
                        _update_log(
                            supabase,
                            log_id,
                            status="running",
                            rows_written=state.total_upserted,
                            metadata=_heartbeat_meta(state),
                        )
                        state.last_heartbeat = _now()
                    except Exception as e:
                        log.warning(f"Heartbeat update failed: {e}")
                elif state.last_heartbeat is None:
                    state.last_heartbeat = _now()

                if once or state.stop_requested:
                    break

                elapsed = time.monotonic() - tick_start
                sleep_for = max(0.0, POLL_INTERVAL_SECONDS - elapsed)
                if sleep_for > 0:
                    time.sleep(sleep_for)

        if supabase is not None and log_id is not None:
            status = "stopped" if state.stop_requested else "success"
            _update_log(
                supabase,
                log_id,
                status=status,
                rows_written=state.total_upserted,
                metadata=_heartbeat_meta(state),
                finish=True,
            )

        log.info(
            f"Done. ticks={state.ticks} "
            f"upserted={state.total_upserted} ended={state.total_ended}"
        )
        return state.total_upserted

    except Exception as e:
        log.exception("Worker fatal")
        if supabase is not None and log_id is not None:
            try:
                _update_log(
                    supabase,
                    log_id,
                    status="failed",
                    rows_written=state.total_upserted,
                    metadata=_heartbeat_meta(state),
                    error=f"{type(e).__name__}: {e}",
                    finish=True,
                )
            except Exception:
                pass
        raise


def _parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="BWF live-tournaments worker (10초 주기 vue-current-live polling)"
    )
    p.add_argument(
        "--year",
        type=int,
        default=None,
        help="Calendar year used for the SPA entry URL (default: current UTC year)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print captured payload; do not write to Supabase",
    )
    p.add_argument(
        "--once",
        action="store_true",
        help="Run one tick and exit (for testing)",
    )
    p.add_argument(
        "--headed",
        action="store_true",
        help="Show the browser window (debug)",
    )
    return p.parse_args()


def main() -> None:
    args = _parse_args()
    run(
        year=args.year,
        dry_run=args.dry_run,
        once=args.once,
        headless=not args.headed,
    )


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception:
        sys.exit(1)
