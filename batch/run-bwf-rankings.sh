#!/usr/bin/env bash
# Local runner for BWF rankings crawl job.
# Usage: ./batch/run-bwf-rankings.sh
# - Creates venv on first run, installs deps, installs Playwright Chromium.
# - Loads batch/.env (must contain SUPABASE_URL + SUPABASE_SERVICE_KEY).
# - Runs the crawler from the project root with PYTHONPATH=.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
ENV_FILE="$SCRIPT_DIR/.env"
REQ_FILE="$SCRIPT_DIR/requirements.txt"
STAMP_FILE="$VENV_DIR/.requirements.sha"

log() { printf "\033[36m[run-bwf-rankings]\033[0m %s\n" "$*"; }
die() { printf "\033[31m[run-bwf-rankings]\033[0m %s\n" "$*" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || die ".env not found at $ENV_FILE (copy from .env.example and fill in)"

if [[ ! -d "$VENV_DIR" ]]; then
  log "Creating venv at $VENV_DIR"
  python3 -m venv "$VENV_DIR"
fi

# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

REQ_SHA="$(shasum -a 256 "$REQ_FILE" | awk '{print $1}')"
if [[ ! -f "$STAMP_FILE" ]] || [[ "$(cat "$STAMP_FILE")" != "$REQ_SHA" ]]; then
  log "Installing/updating Python dependencies"
  pip install --quiet --upgrade pip
  pip install --quiet -r "$REQ_FILE"
  log "Installing Playwright Chromium (idempotent)"
  playwright install chromium
  echo "$REQ_SHA" > "$STAMP_FILE"
else
  log "Dependencies up to date (skipping install)"
fi

cd "$ROOT_DIR"
log "Running batch.jobs.bwf_rankings.main"
PYTHONPATH=. python -u -m batch.jobs.bwf_rankings.main
