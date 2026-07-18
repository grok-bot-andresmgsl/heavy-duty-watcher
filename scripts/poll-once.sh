#!/usr/bin/env bash
# Single headless poll via Grok for the heavy-duty org watcher.
set -euo pipefail

WATCHER_DIR="${WATCHER_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
LOG_DIR="${WATCHER_DIR}/logs"
mkdir -p "${LOG_DIR}"
TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
PROMPT_FILE="${WATCHER_DIR}/.poll-prompt.txt"

cat > "${PROMPT_FILE}" <<EOF
Execute ONE full poll cycle for the heavy-duty org GitHub watcher.

1. Read ${WATCHER_DIR}/POLL_INSTRUCTIONS.md and ${WATCHER_DIR}/state.json
2. Bot: grok-bot-andresmgsl. Scope: ALL repos under org heavy-duty (not a single repo).
3. Discover open Issues/PRs where bot is assignee OR review-requested:
   gh search prs --owner heavy-duty --review-requested=@me --state open --json number,title,url,updatedAt,author,assignees,repository --limit 50
   gh search prs --owner heavy-duty --assignee=@me --state open --json number,title,url,updatedAt,author,assignees,repository --limit 50
   gh search issues --owner heavy-duty --assignee=@me --state open --json number,title,url,updatedAt,author,assignees,repository --limit 50
4. For each match: read ALL comments/reviews/inline threads/diff/checks first; never repeat prior grok-bot-andresmgsl comments.
5. Comment/review only if first assignment, new commits (head SHA change vs state), new human comments needing reply, material CI change, or explicit re-request. Else silent.
6. Style: clear Verdict (Approve/Comment/Request changes) or Status (Aligned/Feedback/Need info). Specific, non-redundant, actionable. Blockers vs nits. Prefer gh pr review. Keep reviewing across updates until you fully agree (then Approve).
7. Never merge/close/reassign/drive-by on unassigned items.
8. Update ${WATCHER_DIR}/state.json (keys like heavy-duty/box#pr:79) + append one line to ${WATCHER_DIR}/logs/poll.log
9. Brief report only. If zero assignments, log and exit.
EOF

echo "[${TS}] poll-once.sh starting headless grok (org:heavy-duty)" >> "${LOG_DIR}/poll.log"

if grok --always-approve --cwd "${HOME}" --max-turns 80 \
  --single "$(cat "${PROMPT_FILE}")" \
  >> "${LOG_DIR}/poll-headless.log" 2>&1; then
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] poll-once.sh finished ok" >> "${LOG_DIR}/poll.log"
else
  rc=$?
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] poll-once.sh failed rc=${rc}" >> "${LOG_DIR}/poll.log"
  exit "${rc}"
fi
