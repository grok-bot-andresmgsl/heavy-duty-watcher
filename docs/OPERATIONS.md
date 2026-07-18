# Operations runbook

## First-time setup

```bash
# 1. Clone
git clone https://github.com/grok-bot-andresmgsl/heavy-duty-watcher.git
cd heavy-duty-watcher

# 2. Auth
gh auth status   # must be grok-bot-andresmgsl (or your reviewer bot)

# 3. Install live + start tmux loops
./scripts/install-live.sh

# 4. In a Grok session: arm durable schedulers (15m poll + 1h health)
#    Or restore interactive session:
./scripts/restore.sh
```

## After PC reboot / box restart

```bash
gh auth status
~/heavy-duty-watcher/scripts/restore.sh
# or:
~/heavy-duty-watcher/scripts/restore.sh --status
```

## Day-to-day

```bash
# What is waiting for us right now?
./scripts/discover.sh

# One-shot health
./scripts/health-check.sh

# Follow activity
tail -f logs/poll.log logs/health.log

# Attach tmux
tmux attach -t heavy-duty-watcher
```

## Schedulers (Grok)

When the agent is live, it should keep two durable recurring tasks:

1. **Poll every 15 minutes** — org-wide discovery + review
2. **Health every 1 hour** — `health-check.sh` + self-heal poll-loop

If either disappears, re-create from the prompts in `docs/SCHEDULER_PROMPTS.md`.

## Migration from `~/rig-watcher`

The original single-repo install lived at `~/rig-watcher`.  
`install-live.sh` can symlink `~/rig-watcher` → `~/heavy-duty-watcher` for compatibility.  
Item keys changed from `pr:N` to `heavy-duty/rig#pr:N`.

## Troubleshooting

| Symptom | Check |
|---------|--------|
| No reviews happening | `./scripts/discover.sh` empty? Not requested. |
| Stale last_poll | `health-check.sh` WARN; is poll-loop alive? |
| gh 401 | `gh auth login` |
| Duplicate spam | Inspect `state.json` `last_head_sha` / `last_action` |
| Scheduler missing | Re-arm via Grok; see `docs/SCHEDULER_PROMPTS.md` |
