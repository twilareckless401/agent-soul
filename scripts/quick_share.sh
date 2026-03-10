#!/usr/bin/env bash
# Quick-share: add one event, compile, and push immediately.
# Use when a fact must reach other agents now, not at the next compile cycle.
#
# Usage:
#   bash scripts/quick_share.sh \
#     --source YOUR_SOURCE_ID --kind decision --scope stable \
#     --summary "We decided X" [--project NAME] [--importance 0.8]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v python3 &>/dev/null; then PYTHON=python3; else PYTHON=python; fi

# 1) Validate and append the event
"$PYTHON" scripts/add_event.py "$@"

# 2) Pull latest to minimise conflicts
git fetch origin main
git merge --ff-only origin/main

# 3) Compile canonical
"$PYTHON" scripts/compile_memory_hub.py --apply

# 4) Stage and guard
git add canonical sources
if git diff --cached --quiet; then
  echo "NO_CHANGES"
  exit 0
fi

git commit -m "chore(memory): quick-share event"

# 5) Push with retry
for attempt in 1 2 3; do
  if git push origin main; then
    echo "QUICK_SHARE_DONE"
    exit 0
  fi
  echo "push failed (attempt $attempt/3), rebasing..."
  git fetch origin main
  git rebase origin/main
  "$PYTHON" scripts/compile_memory_hub.py --apply
  git add canonical sources
  if ! git diff --cached --quiet; then
    git commit -m "chore(memory): recompile after rebase"
  fi
done

echo "PUSH_FAILED after 3 attempts" >&2
exit 1
