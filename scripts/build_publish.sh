#!/usr/bin/env bash
set -euo pipefail

# build_publish.sh — Clean build a Jupyter Book, publish gh-pages, commit+push sources.
# Usage:
#   ./scripts/build_publish.sh [-m "commit msg"] [--no-clean] [--builder html] [BOOK_DIR]
#
# Notes:
# - Requires: jupyter-book, ghp-import, git
# - BOOK_DIR defaults to <repo_root>/textbook
# - ghp-import force-pushes to gh-pages; disable branch protection if enabled.

COMMIT_MSG="build: textbook $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
CLEAN=1
BUILDER=""
BOOK_DIR=""

# Uncomment to auto-activate a conda env if you want:
# if command -v conda >/dev/null 2>&1; then conda activate labenv || true; fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--message) shift; COMMIT_MSG="${1:?missing message}"; shift ;;
    --no-clean) CLEAN=0; shift ;;
    --builder) shift; BUILDER="${1:?missing builder}"; shift ;;
    -h|--help)
      sed -n '1,30p' "$0"; exit 0 ;;
    *) BOOK_DIR="$1"; shift ;;
  esac
done

# Resolve repo root and book dir
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "ERROR: Not inside a git repository." >&2; exit 1; }
[[ -n "$BOOK_DIR" ]] || BOOK_DIR="$REPO_ROOT"
[[ -d "$BOOK_DIR" ]] || { echo "ERROR: Book dir not found: $BOOK_DIR" >&2; exit 1; }

# Tool checks
command -v jupyter-book >/dev/null || { echo "ERROR: jupyter-book not found." >&2; exit 1; }
command -v ghp-import  >/dev/null || { echo "ERROR: ghp-import not found."  >&2; exit 1; }
command -v git         >/dev/null || { echo "ERROR: git not found."         >&2; exit 1; }

echo "Repo: $REPO_ROOT"
echo "Book: $BOOK_DIR"

pushd "$BOOK_DIR" >/dev/null
if [[ $CLEAN -eq 1 ]]; then
  echo "→ Cleaning caches"
  jupyter-book clean --all .
fi

echo "→ Building Jupyter Book"
if [[ -n "$BUILDER" ]]; then
  jupyter-book build --builder "$BUILDER" .
else
  jupyter-book build .
fi

echo "→ Publishing to gh-pages (force push)"
ghp-import -n -p -f _build/html
popd >/dev/null

# Commit & push source changes on current branch
pushd "$REPO_ROOT" >/dev/null
echo "→ Committing source changes"
git add -A
if git diff --cached --quiet; then
  echo "✓ No source changes to commit."
else
  git commit -m "$COMMIT_MSG"
  echo "→ Pushing source branch"
  git push
fi
popd >/dev/null

echo "✓ Done."

