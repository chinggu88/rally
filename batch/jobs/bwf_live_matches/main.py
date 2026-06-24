"""BWF live matches worker — 10초 주기 vue-live-matches 캡처.

흐름 (2026-06 개편):
  1. 부모 토너먼트 선택: Supabase bwf_tournaments에서 start_date ≤ today ≤
     end_date 인 행을 직접 조회 (5분 캐시). 기존 vue-current-live SPA 캡처 단계
     제거 — 캘린더 잡이 이미 채워두는 테이블을 신뢰한다.
  2. 각 활성 대회마다 match-centre SPA(/match-centre.bwfbadminton.com/{tid})
     를 띄우고 SPA가 자동 호출하는 vue-live-matches JSON을 page.on('response')로
     가로챈다. Cloudflare JA3 검사로 직접 호출은 불가하므로 이 우회만 유일하게
     200을 받는다.
  3. parse_live_matches로 bwf_live_matches row를 만들고 upsert. 라이브 응답에서
     사라진 매치는 promoted_at으로 소프트 삭제(mark_ended).

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

from batch.jobs.bwf_live_matches.fetcher import LiveMatchCentreSession
from batch.jobs.bwf_live_matches.parser import parse_live_matches
from batch.jobs.bwf_live_matches.upserter import mark_ended, upsert_live_matches
from batch.shared.logger import get_logger
from batch.shared.supabase_client import get_client

JOB_NAME = "bwf_live_matches"

POLL_INTERVAL_SECONDS = 10
HEARTBEAT_INTERVAL_MINUTES = 60
# 활성 대회 목록(bwf_tournaments 날짜 필터)은 자주 안 바뀌므로 N초 캐시 후 재조회.
# 대회 시작/종료는 분 단위로 변하지 않아 5분이면 충분히 최신.
ACTIVE_TOURNAMENTS_REFRESH_SECONDS = 300

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
        # 활성 대회 캐시 — bwf_tournaments에서 5분에 한 번만 조회.
        self.cached_tournaments: list[dict[str, Any]] = []
        self.tournaments_cached_at: datetime | None = None


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


# ---- Active tournaments (bwf_tournaments date filter) ---------------------


# 매치 row에 동봉할 대회 컨텍스트 컬럼들. raw는 페이로드 크기 절약 차원에서 제외.
_TOURNAMENT_COLUMNS = (
    "tournament_id, code, name, tour_level, category_id, "
    "start_date, end_date, date_label, country, location, "
    "prize_money_usd, detail_url, logo_url, cat_logo_url"
)


def _tournaments_stale(state: WorkerState) -> bool:
    if state.tournaments_cached_at is None:
        return True
    age = (_now() - state.tournaments_cached_at).total_seconds()
    return age > ACTIVE_TOURNAMENTS_REFRESH_SECONDS


def _fetch_active_tournaments(supabase: Any) -> list[dict[str, Any]]:
    """start_date ≤ today ≤ end_date 인 bwf_tournaments 행을 조회.

    `today`는 UTC 기준. BWF 대회 일정은 일 단위라 시간대 차이는 무시한다.
    """
    today = _now().date().isoformat()
    res = (
        supabase.table("bwf_tournaments")
        .select(_TOURNAMENT_COLUMNS)
        .lte("start_date", today)
        .gte("end_date", today)
        .execute()
    )
    return list(getattr(res, "data", None) or [])


# ---- One tick -------------------------------------------------------------


def _run_one_tick(
    session: LiveMatchCentreSession,
    supabase: Any,
    log,
    state: WorkerState,
    dry_run: bool,
) -> None:
    # 1) 활성 대회 캐시 갱신 (5분 주기). dry-run이면 매 호출 새로 가져온다 — 매번
    #    최신 상태를 보고 확인하는 게 dry-run의 목적이므로.
    if supabase is not None and (_tournaments_stale(state) or dry_run):
        try:
            state.cached_tournaments = _fetch_active_tournaments(supabase)
            state.tournaments_cached_at = _now()
            log.info(
                f"active tournaments refreshed: {len(state.cached_tournaments)} row(s)"
            )
        except Exception as e:
            log.warning(
                f"bwf_tournaments query failed: {type(e).__name__}: {e}; "
                f"reusing previous cache (size={len(state.cached_tournaments)})"
            )

    tournaments = state.cached_tournaments
    if not tournaments:
        log.info("no active tournaments for today")
        return

    # 2) 대회별 vue-live-matches 캡처 → 매치 row로 변환
    # polled_tournament_ids = 응답을 정상 캡처한 대회. payload=None은 캡처 실패로
    # 분류해 mark_ended sweep에서 제외(전역 폭주 방지).
    all_matches: list[dict[str, Any]] = []
    per_tournament: list[tuple[str, int, int]] = []  # (name, tid, match_count)
    polled_tournament_ids: list[int] = []
    for t in tournaments:
        tid = t.get("tournament_id")
        if not isinstance(tid, int):
            continue
        try:
            payload = session.fetch_live_matches(tid)
        except Exception as e:
            log.warning(
                f"vue-live-matches capture failed tid={tid}: {type(e).__name__}: {e}"
            )
            continue
        if payload is None:
            log.warning(f"vue-live-matches capture returned None tid={tid}")
            continue
        polled_tournament_ids.append(tid)
        state.last_capture_ok = _now()
        matches = parse_live_matches(payload, t)
        all_matches.extend(matches)
        per_tournament.append((t.get("name") or "", tid, len(matches)))

    active_match_ids = [m["id"] for m in all_matches]
    state.last_active_ids = active_match_ids

    if dry_run:
        sample = {
            "tournaments": [
                {"tournament_id": t.get("tournament_id"), "name": t.get("name")}
                for t in tournaments
            ],
            "matches_preview": [
                {k: v for k, v in m.items() if k != "raw"}
                for m in all_matches[:3]
            ],
            "per_tournament": per_tournament,
        }
        print(json.dumps(sample, ensure_ascii=False, indent=2, default=str))
        log.info(
            f"dry-run — would upsert {len(all_matches)} live match(es) "
            f"across {len(polled_tournament_ids)} tournament(s)"
        )
        return

    written = upsert_live_matches(supabase, all_matches)
    state.total_upserted += written

    # 캡처 성공한 대회 경계 안에서만 mark_ended sweep.
    if polled_tournament_ids:
        ended = mark_ended(
            supabase, active_match_ids, log,
            polled_tournament_ids=polled_tournament_ids,
        )
        state.total_ended += ended
    else:
        ended = 0
        log.info("skipping mark_ended: no vue-live-matches captured this tick")
    log.info(
        f"tick {state.ticks}: matches_upserted={written} "
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
    dry_run: bool = False,
    once: bool = False,
    headless: bool = True,
) -> int:
    if BATCH_ENV.exists():
        load_dotenv(BATCH_ENV)
    else:
        load_dotenv()

    log = get_logger(JOB_NAME)
    log.info(
        f"Starting {JOB_NAME} (dry_run={dry_run}, once={once}, headless={headless})"
    )

    # dry-run도 활성 대회 조회는 필요하므로 Supabase 클라이언트는 항상 필요.
    supabase = get_client()
    state = WorkerState()
    log_id: int | None = None

    if not dry_run and not once:
        log_id = _start_log(
            supabase,
            metadata={"poll_interval_seconds": POLL_INTERVAL_SECONDS},
        )
        _install_signal_handlers(state, log)

    try:
        with LiveMatchCentreSession(headless=headless) as session:
            while True:
                tick_start = time.monotonic()
                state.ticks += 1
                try:
                    _run_one_tick(session, supabase, log, state, dry_run)
                except Exception as e:
                    log.exception(f"Tick {state.ticks} crashed: {e}")

                if (
                    not dry_run
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

        if not dry_run and log_id is not None:
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
        if not dry_run and log_id is not None:
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
        description="BWF live-matches worker (10초 주기 vue-live-matches polling)"
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
