#!/usr/bin/env bash
# Long-running poll loop (default 15 minutes) for tmux.
set -euo pipefail

WATCHER_DIR="${WATCHER_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_DIR="${WATCHER_DIR}/logs"
INTERVAL_SEC="${POLL_INTERVAL_SEC:-900}"
mkdir -p "${LOG_DIR}"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] poll-loop started interval=${INTERVAL_SEC}s scope=org:heavy-duty (sleep-first)" \
  >> "${LOG_DIR}/poll.log"

if [[ "${POLL_NOW:-0}" == "1" ]]; then
  "${WATCHER_DIR}/scripts/poll-once.sh" || true
fi

while true; do
  sleep "${INTERVAL_SEC}"
  if ps -eo args | awk '/heavy-duty-watcher\/scripts\/poll-once\.sh/ && !/awk/ {found=1} END{exit !found}'; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] poll-loop: previous poll still running, skipping" >> "${LOG_DIR}/poll.log"
  else
    "${WATCHER_DIR}/scripts/poll-once.sh" || true
  fi
done
