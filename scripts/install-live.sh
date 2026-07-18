#!/usr/bin/env bash
# Install/refresh the live watcher under $HOME/heavy-duty-watcher and start tmux loops.
set -euo pipefail

SRC="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${DEST:-$HOME/heavy-duty-watcher}"
TMUX_SESSION="${TMUX_SESSION:-heavy-duty-watcher}"

echo "Installing watcher: ${SRC} -> ${DEST}"
mkdir -p "${DEST}"
# Copy tree but preserve local state/logs if DEST already has them
rsync -a --exclude '.git' --exclude 'state.json' --exclude 'logs/' --exclude '.poll-prompt.txt' \
  "${SRC}/" "${DEST}/"

mkdir -p "${DEST}/logs"
if [[ ! -f "${DEST}/state.json" ]]; then
  NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg t "$NOW" '.created_at=$t | .last_poll_at=null' \
    "${DEST}/config/state.template.json" > "${DEST}/state.json"
  echo "seeded state.json"
fi

chmod +x "${DEST}/scripts/"*.sh

# Compatibility symlink for old path
if [[ ! -e "$HOME/rig-watcher" ]]; then
  ln -s "${DEST}" "$HOME/rig-watcher"
  echo "linked ~/rig-watcher -> ${DEST}"
fi

# Ensure tmux loops
if tmux has-session -t "${TMUX_SESSION}" 2>/dev/null; then
  echo "tmux ${TMUX_SESSION} already exists"
else
  tmux new-session -d -s "${TMUX_SESSION}" -n poll-loop -c "${DEST}" \
    "bash ${DEST}/scripts/poll-loop.sh"
  tmux new-window -t "${TMUX_SESSION}" -n health-loop -c "${DEST}" \
    "bash ${DEST}/scripts/health-loop.sh"
  tmux new-window -t "${TMUX_SESSION}" -n tools -c "${DEST}" \
    "echo 'heavy-duty-watcher tools'; exec bash"
  echo "started tmux session ${TMUX_SESSION}"
fi

bash "${DEST}/scripts/health-check.sh" || true
echo "Live install ready. Restore after reboot: ${DEST}/scripts/restore.sh"
