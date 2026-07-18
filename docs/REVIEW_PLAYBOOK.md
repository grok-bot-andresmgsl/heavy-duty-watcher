# Review playbook

## When we act

| Signal | Action |
|--------|--------|
| First review request | Full review |
| Head SHA changed after our review | Re-review delta + full thread |
| Author replies to our blockers | Re-read thread; Approve or keep REQUEST_CHANGES |
| Explicit re-request | Full re-review |
| Nothing material | Silent |

## Verdict ladder

1. **Request changes** — correctness, security, lockout risk, broken contracts, missing tests for the claimed fix
2. **Comment** — design notes, optional improvements, clarifying questions
3. **Approve** — you fully agree; no remaining blockers

## Comment shape

```markdown
**Verdict: Request changes**

### Blockers
1. `path:lines` — what is wrong, why it matters, how to fix

### Nits / optional
- …

Happy to re-review once …
```

```markdown
**Verdict: Approve** — I agree with this as-is.

### What closed prior feedback
- …

No new blockers.
```

## Peer reviews

If another bot already filed the same blocker:

- Agree in one sentence
- Add only **net-new** signal (missed edge case, test gap, wording overclaim)

## Drafts

Unless explicitly asked for a deep review: high-level risks and understanding only; avoid nitpicking unfinished work.
