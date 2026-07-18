#!/usr/bin/env bash
# Restore the heavy-duty org watcher after reboot / session loss.
# Usage:
#   ./scripts/restore.sh           # create/attach tmux + resume Grok
#   ./scripts/restore.sh --attach  # attach only
#   ./scripts/restore.sh --status  # health snapshot
set -euo pipefail

WATCHER_DIR="${WATCHER_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_FILE="${WATCHER_DIR}/state.json"
TMUX_SESSION="${TMUX_SESSION:-heavy-duty-watcher}"
LOG_DIR="${WATCHER_DIR}/logs"
mkdir -p "${LOG_DIR}"

session_id() {
  if [[ -f "${STATE_FILE}" ]] && command -v jq >/dev/null 2>&1; then
    local id
    id="$(jq -r '.session_id // empty' "${STATE_FILE}" 2>/dev/null || true)"
    if [[ -n "${id}" && "${id}" != "null" ]]; then
      echo "${id}"
      return
    fi
  fi
  echo ""
}

status() {
  echo "=== heavy-duty-watcher status ==="
  echo "dir: ${WATCHER_DIR}"
  if [[ -f "${STATE_FILE}" ]]; then
    jq '{scope, org, bot_login, session_id, last_poll_at, last_poll_summary, health, items: (.items|keys)}' \
      "${STATE_FILE}" 2>/dev/null || cat "${STATE_FILE}"
  else
    echo "(missing state.json)"
  fi
  echo
  tmux ls 2>/dev/null || echo "(no tmux sessions)"
  echo
  echo "gh user: $(gh api user --jq .login 2>/dev/null || echo 'not authenticated')"
  echo "session_id: $(session_id || true)"
  [[ -f "${LOG_DIR}/poll.log" ]] && { echo; echo "last poll log:"; tail -n 5 "${LOG_DIR}/poll.log"; }
  [[ -f "${LOG_DIR}/health.log" ]] && { echo; echo "last health log:"; tail -n 5 "${LOG_DIR}/health.log"; }
  bash "${WATCHER_DIR}/scripts/health-check.sh" || true
}

attach_only() {
  if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
    exec tmux attach -t "${TMUX_SESSION}"
  fi
  echo "tmux session '${TMUX_SESSION}' not running. Run without --attach to start."
  exit 1
}

start_or_attach() {
  local sid resume_prompt
  sid="$(session_id)"
  resume_prompt="$(cat <<EOF
Resume the heavy-duty org GitHub watcher (ALL heavy-duty/* repos).

1. Read ${WATCHER_DIR}/POLL_INSTRUCTIONS.md and ${WATCHER_DIR}/state.json
2. Run one full org-wide poll cycle immediately (discover assigned/review-requested across org, read all comments, review until you agree)
3. Re-arm durable schedulers:
   - 15m poll (org-wide, durable true)
   - 1h health watchdog (durable true)
4. Confirm poll-loop + health-loop windows are running
5. Report status

Do not merge, close, or reassign unless explicitly asked.
EOF
)"

  if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
    if ! tmux list-windows -t "${TMUX_SESSION}" -F '#{window_name}' 2>/dev/null | grep -qx 'poll-loop'; then
      tmux new-window -t "${TMUX_SESSION}" -n poll-loop -c "${WATCHER_DIR}" \
        "bash ${WATCHER_DIR}/scripts/poll-loop.sh"
    fi
    if ! tmux list-windows -t "${TMUX_SESSION}" -F '#{window_name}' 2>/dev/null | grep -qx 'health-loop'; then
      tmux new-window -t "${TMUX_SESSION}" -n health-loop -c "${WATCHER_DIR}" \
        "bash ${WATCHER_DIR}/scripts/health-loop.sh"
    fi
    echo "tmux session '${TMUX_SESSION}' exists — attaching."
    exec tmux attach -t "${TMUX_SESSION}"
  fi

  echo "Creating tmux session '${TMUX_SESSION}'..."
  local grok_cmd
  if [[ -n "${sid}" ]]; then
    grok_cmd="grok -r ${sid} --cwd ${HOME} $(printf %q "${resume_prompt}") || grok -c --cwd ${HOME} $(printf %q "${resume_prompt}") || grok --cwd ${HOME} $(printf %q "${resume_prompt}")"
  else
    grok_cmd="grok --cwd ${HOME} $(printf %q "${resume_prompt}")"
  fi

  tmux new-session -d -s "${TMUX_SESSION}" -n grok -c "${HOME}" \
    "${grok_cmd}; echo; echo '[heavy-duty-watcher] Grok exited.'; exec bash"

  tmux new-window -t "${TMUX_SESSION}" -n poll-loop -c "${WATCHER_DIR}" \
    "bash ${WATCHER_DIR}/scripts/poll-loop.sh"

  tmux new-window -t "${TMUX_SESSION}" -n health-loop -c "${WATCHER_DIR}" \
    "bash ${WATCHER_DIR}/scripts/health-loop.sh"

  tmux new-window -t "${TMUX_SESSION}" -n tools -c "${WATCHER_DIR}" \
    "echo 'tools: ./scripts/discover.sh | ./scripts/health-check.sh | tail -f logs/poll.log'; exec bash"

  tmux select-window -t "${TMUX_SESSION}:grok"
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) restore.sh started ${TMUX_SESSION}" >> "${LOG_DIR}/poll.log"
  exec tmux attach -t "${TMUX_SESSION}"
}

case "${1:-}" in
  --status|-s) status ;;
  --attach|-a) attach_only ;;
  --help|-h) sed -n '2,7p' "$0" ;;
  *) start_or_attach ;;
esac
