#!/usr/bin/env bash
# Full compile cycle: pull latest, compile canonical, push.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v python3 &>/dev/null; then PYTHON=python3; else PYTHON=python; fi

# 1) Pull latest
git fetch origin main
git merge --ff-only origin/main

# 2) Compile canonical from sources
"$PYTHON" scripts/compile_memory_hub.py --apply

# 3) Stage changes
git add canonical sources
if git diff --cached --quiet; then
  echo "NO_CHANGES"
  exit 0
fi

# 4) Commit and push with retry
git commit -m "chore(memory): compile canonical from sources"

for attempt in 1 2 3; do
  if git push origin main; then
    echo "CHANGES_PUSHED"
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
