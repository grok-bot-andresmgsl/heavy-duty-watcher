# Architecture

## What this is

A **durable, org-wide GitHub review agent** for [heavy-duty](https://github.com/heavy-duty).

It polls GitHub for Issues/PRs where bot **`grok-bot-andresmgsl`** is:

- requested as **reviewer**, or
- **assignee**

…across **every repository** in the organization. It reads full thread history, reviews diffs, and posts structured feedback until it can **Approve**.

## Components

```text
┌─────────────────────────────────────────────────────────────┐
│  Grok durable scheduler (15m)  ──►  poll cycle (interactive) │
│  Grok durable scheduler (1h)   ──►  health watchdog           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  tmux session: heavy-duty-watcher                           │
│   ├─ poll-loop   (scripts/poll-loop.sh → poll-once.sh)      │
│   ├─ health-loop (scripts/health-loop.sh → health-check.sh) │
│   ├─ tools       (manual gh / logs)                         │
│   └─ grok        (optional interactive resume)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                     GitHub org:heavy-duty
                     state.json + logs/
```

### Why two poll paths?

| Path | Survives |
|------|----------|
| Grok durable scheduler | New Grok sessions (durable flag); may need re-arm after ~7 days |
| Local `poll-loop.sh` in tmux | Box uptime; independent of Grok UI |

After reboot: run `scripts/restore.sh`.

## State model

`state.json` is the single source of truth for de-duplication:

```json
{
  "scope": "org:heavy-duty",
  "items": {
    "heavy-duty/box#pr:79": {
      "last_head_sha": "abc…",
      "last_action": "reviewed",
      "review_event": "REQUEST_CHANGES"
    }
  }
}
```

Keys are always `owner/repo#pr:N` or `owner/repo#issue:N` so multiple repos never collide.

## Review policy (summary)

Full rules live in [`../POLL_INSTRUCTIONS.md`](../POLL_INSTRUCTIONS.md).

- Act only when assignee or review-requested
- Read **all** comments before speaking
- Clear **Verdict** / **Status** line first
- **Request changes** until agreement; **Approve** when fully satisfied
- Silent when nothing material changed

## Security / safety

- No merge / close / force-push / reassignment unless operator asks
- Uses the bot’s GitHub token via `gh` / MCP
- Does not store secrets in the repo (state is operational metadata only)
