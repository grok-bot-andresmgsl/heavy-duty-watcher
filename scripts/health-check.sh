#!/usr/bin/env bash
# Health check for the heavy-duty org watcher. Exit 0=ok, 1=degraded, 2=down.
set -euo pipefail

WATCHER_DIR="${WATCHER_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_FILE="${WATCHER_DIR}/state.json"
LOG_DIR="${WATCHER_DIR}/logs"
HEALTH_LOG="${LOG_DIR}/health.log"
TMUX_SESSION="${TMUX_SESSION:-heavy-duty-watcher}"
# Accept legacy session name during migration
LEGACY_TMUX="${LEGACY_TMUX:-rig-watcher}"
STALE_POLL_MINUTES="${STALE_POLL_MINUTES:-45}"
mkdir -p "${LOG_DIR}"

NOW_EPOCH="$(date -u +%s)"
NOW_ISO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
STATUS="ok"
ISSUES=()

ok()   { ISSUES+=("OK: $1"); }
warn() { STATUS="degraded"; ISSUES+=("WARN: $1"); }
fail() { STATUS="down"; ISSUES+=("FAIL: $1"); }

if gh api user --jq .login >/dev/null 2>&1; then
  LOGIN="$(gh api user --jq .login 2>/dev/null || echo unknown)"
  ok "gh authenticated as ${LOGIN}"
else
  fail "gh not authenticated"
fi

ACTIVE_TMUX=""
if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
  ACTIVE_TMUX="${TMUX_SESSION}"
elif tmux has-session -t "${LEGACY_TMUX}" 2>/dev/null; then
  ACTIVE_TMUX="${LEGACY_TMUX}"
  warn "using legacy tmux session ${LEGACY_TMUX} (prefer ${TMUX_SESSION})"
fi

if [[ -n "${ACTIVE_TMUX}" ]]; then
  ok "tmux session ${ACTIVE_TMUX} exists"
  if tmux list-windows -t "${ACTIVE_TMUX}" -F '#{window_name}' 2>/dev/null | grep -Eqx 'poll-loop'; then
    ok "tmux window poll-loop present"
  else
    warn "tmux window poll-loop missing"
  fi
else
  fail "tmux session missing (run scripts/restore.sh)"
fi

if ps -eo args | awk '/poll-loop\.sh/ && !/awk/ {found=1} END{exit !found}'; then
  ok "poll-loop.sh process running"
else
  fail "poll-loop.sh process not running"
fi

if [[ -f "${STATE_FILE}" ]]; then
  LAST_POLL="$(jq -r '.last_poll_at // empty' "${STATE_FILE}" 2>/dev/null || true)"
  SCOPE="$(jq -r '.scope // .repo // "unknown"' "${STATE_FILE}" 2>/dev/null || echo unknown)"
  ok "scope: ${SCOPE}"
  if [[ -n "${LAST_POLL}" ]]; then
    if LAST_EPOCH="$(date -u -d "${LAST_POLL}" +%s 2>/dev/null)"; then
      AGE_MIN=$(( (NOW_EPOCH - LAST_EPOCH) / 60 ))
      if (( AGE_MIN > STALE_POLL_MINUTES )); then
        warn "last_poll_at is ${AGE_MIN}m old (${LAST_POLL})"
      else
        ok "last_poll_at fresh (${AGE_MIN}m ago: ${LAST_POLL})"
      fi
    else
      ok "last_poll_at present (${LAST_POLL})"
    fi
  else
    warn "state.json has no last_poll_at"
  fi
  SUMMARY="$(jq -r '.last_poll_summary // "n/a"' "${STATE_FILE}" 2>/dev/null || echo n/a)"
  ok "last_poll_summary: ${SUMMARY}"
else
  fail "state.json missing"
fi

[[ -f "${WATCHER_DIR}/POLL_INSTRUCTIONS.md" ]] && ok "POLL_INSTRUCTIONS.md present" || fail "POLL_INSTRUCTIONS.md missing"

RESULT_JSON="${LOG_DIR}/health-latest.json"
{
  echo "{"
  echo "  \"checked_at\": \"${NOW_ISO}\","
  echo "  \"status\": \"${STATUS}\","
  echo "  \"issues\": ["
  first=1
  for line in "${ISSUES[@]}"; do
    esc="${line//\"/\\\"}"
    if (( first )); then first=0; else echo ","; fi
    printf '    "%s"' "${esc}"
  done
  echo
  echo "  ]"
  echo "}"
} > "${RESULT_JSON}"

echo "[${NOW_ISO}] status=${STATUS} | $(IFS=' ; '; echo "${ISSUES[*]}")" >> "${HEALTH_LOG}"

if command -v jq >/dev/null 2>&1 && [[ -f "${STATE_FILE}" ]]; then
  tmp="$(mktemp)"
  jq --arg t "${NOW_ISO}" --arg s "${STATUS}" \
    '.health = {last_check_at: $t, status: $s}' "${STATE_FILE}" > "${tmp}" \
    && mv "${tmp}" "${STATE_FILE}"
fi

echo "status=${STATUS}"
printf '%s\n' "${ISSUES[@]}"
case "${STATUS}" in
  ok) exit 0 ;;
  degraded) exit 1 ;;
  *) exit 2 ;;
esac
