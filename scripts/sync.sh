#!/usr/bin/env bash
# Sync skills between this repo and ~/.claude/skills/
#
# Usage:
#   ./scripts/sync.sh push   — deploy skills/ → ~/.claude/skills/
#   ./scripts/sync.sh pull   — pull ~/.claude/skills/ → skills/

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"

usage() {
  echo "Usage: $0 [push|pull]"
  echo "  push  Deploy skills from repo to ~/.claude/skills/"
  echo "  pull  Pull skills from ~/.claude/skills/ into repo"
  exit 1
}

[ "${1:-}" = "" ] && usage

case "$1" in
  push)
    echo "Deploying skills/ → $SKILLS_DEST"
    for skill_dir in "$SKILLS_SRC"/*/; do
      name=$(basename "$skill_dir")
      echo "  → $name"
      cp -r "$skill_dir" "$SKILLS_DEST/$name"
    done
    echo "Done."
    ;;
  pull)
    echo "Pulling $SKILLS_DEST → skills/"
    for skill_dir in "$SKILLS_DEST"/*/; do
      name=$(basename "$skill_dir")
      echo "  ← $name"
      cp -r "$skill_dir" "$SKILLS_SRC/$name"
    done
    echo "Done. Review changes with: git diff skills/"
    ;;
  *)
    usage
    ;;
esac
