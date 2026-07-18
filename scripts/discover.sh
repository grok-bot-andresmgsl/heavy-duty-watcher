#!/usr/bin/env bash
# Org-wide discovery of actionable PRs/issues for the bot.
set -euo pipefail
ORG="${ORG:-heavy-duty}"
LIMIT="${LIMIT:-50}"

echo "=== review-requested PRs (org:${ORG}) ==="
gh search prs --owner "${ORG}" --review-requested=@me --state open \
  --json number,title,url,updatedAt,author,assignees,repository --limit "${LIMIT}"

echo "=== assignee PRs (org:${ORG}) ==="
gh search prs --owner "${ORG}" --assignee=@me --state open \
  --json number,title,url,updatedAt,author,assignees,repository --limit "${LIMIT}"

echo "=== assignee issues (org:${ORG}) ==="
gh search issues --owner "${ORG}" --assignee=@me --state open \
  --json number,title,url,updatedAt,author,assignees,repository --limit "${LIMIT}"
