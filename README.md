# heavy-duty-watcher

**Org-wide GitHub review agent** for the [heavy-duty](https://github.com/heavy-duty) organization.

Runs as bot **`grok-bot-andresmgsl`**. Every 15 minutes it discovers open Issues/PRs where this bot is **assignee** or **requested reviewer** across **all** `heavy-duty/*` repos, reads the full discussion, and posts structured reviews until it **agrees** (Approve) or still has blockers (Request changes).

> Not a drive-by bot. No unsolicited comments. No merge/close/reassign unless an operator asks.

---

## Features

- **Org-wide scope** — one watcher for every repo under `heavy-duty`
- **Strict collaboration rules** — clear Verdict/Status, specific, non-redundant, blockers vs nits
- **Stateful de-dupe** — tracks per-item head SHA and last action (`owner/repo#pr:N`)
- **Dual durability** — Grok durable schedulers **and** local tmux loops
- **Reboot recovery** — `scripts/restore.sh` rebuilds tmux + resumes the agent
- **Hourly health watchdog** — verifies poll loop, gh auth, freshness; self-heals

---

## Quick start

```bash
git clone https://github.com/grok-bot-andresmgsl/heavy-duty-watcher.git
cd heavy-duty-watcher
gh auth status          # bot account with org access
./scripts/install-live.sh
./scripts/restore.sh    # after reboot: always this
```

Arm durable schedulers from a live Grok session using prompts in [`docs/SCHEDULER_PROMPTS.md`](docs/SCHEDULER_PROMPTS.md).

---

## Repository layout

```text
heavy-duty-watcher/
├── README.md                 ← you are here
├── POLL_INSTRUCTIONS.md      ← authoritative review rules (read every cycle)
├── config/
│   ├── state.template.json
│   └── watcher.env.example
├── scripts/
│   ├── discover.sh           ← org-wide actionable list
│   ├── poll-once.sh          ← one headless poll (Grok)
│   ├── poll-loop.sh          ← every 15m
│   ├── health-check.sh
│   ├── health-loop.sh        ← every 1h + self-heal
│   ├── restore.sh            ← reboot recovery (tmux)
│   └── install-live.sh       ← deploy under ~/heavy-duty-watcher
├── docs/
│   ├── ARCHITECTURE.md
│   ├── OPERATIONS.md
│   ├── SCHEDULER_PROMPTS.md
│   └── REVIEW_PLAYBOOK.md
└── logs/                     ← runtime (gitignored)
```

---

## How a poll works

```text
discover (org search)
   → for each match
        read ALL comments + reviews + diff + checks
        compare head SHA / prior bot comments (state.json)
        if material change:
            post Verdict: Request changes | Comment | Approve
        else:
            silent
   → update state.json + logs/poll.log
```

Full rules: [`POLL_INSTRUCTIONS.md`](POLL_INSTRUCTIONS.md).

---

## Documentation map

| Doc | Audience |
|-----|----------|
| [POLL_INSTRUCTIONS.md](POLL_INSTRUCTIONS.md) | Agent — must follow every cycle |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Design / durability model |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Humans operating the watcher |
| [docs/SCHEDULER_PROMPTS.md](docs/SCHEDULER_PROMPTS.md) | Copy-paste durable task prompts |
| [docs/REVIEW_PLAYBOOK.md](docs/REVIEW_PLAYBOOK.md) | Review style examples |

---

## After reboot

```bash
~/heavy-duty-watcher/scripts/restore.sh
```

Creates/attaches tmux session `heavy-duty-watcher` with:

| Window | Role |
|--------|------|
| `grok` | Interactive agent (resume session when possible) |
| `poll-loop` | Headless 15m polls |
| `health-loop` | Hourly health + self-heal |
| `tools` | Manual shell |

---

## Safety

- Only comments when **assigned** or **review-requested**
- Never merges, closes, force-pushes, or reassigns by default
- Secrets are **not** stored in this repo — use `gh auth` on the host

---

## License

MIT — see [LICENSE](LICENSE).
