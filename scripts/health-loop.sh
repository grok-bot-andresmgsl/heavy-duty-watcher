#!/usr/bin/env bash
# Hourly health check + self-heal for poll-loop.
set -euo pipefail

WATCHER_DIR="${WATCHER_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_DIR="${WATCHER_DIR}/logs"
INTERVAL_SEC="${HEALTH_INTERVAL_SEC:-3600}"
TMUX_SESSION="${TMUX_SESSION:-heavy-duty-watcher}"
LEGACY_TMUX="${LEGACY_TMUX:-rig-watcher}"
mkdir -p "${LOG_DIR}"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] health-loop started interval=${INTERVAL_SEC}s" \
  >> "${LOG_DIR}/health.log"

"${WATCHER_DIR}/scripts/health-check.sh" || true

session_name() {
  if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
    echo "${TMUX_SESSION}"
  elif tmux has-session -t "${LEGACY_TMUX}" 2>/dev/null; then
    echo "${LEGACY_TMUX}"
  else
    echo ""
  fi
}

while true; do
  sleep "${INTERVAL_SEC}"
  set +e
  "${WATCHER_DIR}/scripts/health-check.sh"
  rc=$?
  set -e

  if ! ps -eo args | awk '/poll-loop\.sh/ && !/awk/ {found=1} END{exit !found}'; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] health-loop: restarting poll-loop" \
      >> "${LOG_DIR}/health.log"
    sess="$(session_name)"
    if [[ -n "${sess}" ]]; then
      tmux list-windows -t "${sess}" -F '#{window_index} #{window_name}' \
        | awk '$2=="poll-loop"{print $1}' \
        | while read -r idx; do tmux kill-window -t "${sess}:${idx}" 2>/dev/null || true; done
      tmux new-window -t "${sess}" -n poll-loop -c "${WATCHER_DIR}" \
        "bash ${WATCHER_DIR}/scripts/poll-loop.sh"
    else
      tmux new-session -d -s "${TMUX_SESSION}" -n poll-loop -c "${WATCHER_DIR}" \
        "bash ${WATCHER_DIR}/scripts/poll-loop.sh"
      tmux new-window -t "${TMUX_SESSION}" -n health-loop -c "${WATCHER_DIR}" \
        "bash ${WATCHER_DIR}/scripts/health-loop.sh"
    fi
  fi

  if (( rc != 0 )); then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] health-loop: status non-ok rc=${rc}" \
      >> "${LOG_DIR}/health.log"
  fi
done
