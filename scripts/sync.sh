#!/usr/bin/env bash
# Sync skills and agents between this repo and ~/.claude/
#
# Usage:
#   ./scripts/sync.sh push   — deploy skills/ → ~/.claude/skills/; agents/ → ~/.claude/agents/
#   ./scripts/sync.sh pull   — pull ~/.claude/skills/ → skills/; ~/.claude/agents/ → agents/

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"
AGENTS_SRC="$REPO_DIR/agents"
AGENTS_DEST="$HOME/.claude/agents"
# External skill repos — cloned/updated into REPO_DIR on push.
# Format: "owner/repo:dest_subdir"
EXTERNAL_SKILLS=(
  "dgilford/tab-setup:tab-setup"
)

usage() {
  echo "Usage: $0 [push|pull]"
  echo "  push  Deploy skills from repo to ~/.claude/skills/ and agents to ~/.claude/agents/"
  echo "  pull  Pull skills from ~/.claude/skills/ into repo"
  exit 1
}

sync_external_skills() {
  for entry in "${EXTERNAL_SKILLS[@]}"; do
    local repo="${entry%%:*}"
    local dest="${entry##*:}"
    local dest_path="$REPO_DIR/$dest"
    if [ -d "$dest_path/.git" ]; then
      echo "  ↻ $repo (pull)"
      git -C "$dest_path" pull --ff-only --quiet
    else
      echo "  ↓ $repo (clone)"
      git clone --quiet "https://github.com/$repo" "$dest_path"
    fi
    # Copy scripts (and vscode-extension if present) into the skills deploy dir
    local skill_name
    skill_name=$(basename "$dest")
    mkdir -p "$SKILLS_SRC/$skill_name/scripts"
    cp -r "$dest_path/scripts/." "$SKILLS_SRC/$skill_name/scripts/"
    if [ -d "$dest_path/vscode-extension" ]; then
      mkdir -p "$SKILLS_SRC/$skill_name/vscode-extension"
      cp -r "$dest_path/vscode-extension/." "$SKILLS_SRC/$skill_name/vscode-extension/"
      echo "  → vscode-extension synced"
    fi
  done
}

install_startup_hook() {
  local config_dest="$HOME/.claude/session-init-config.json"
  local hook_cmd="bash ~/.claude/skills/tab-setup/scripts/hook-startup.sh"

  # session-init-config.json is still read by hook-startup.sh for the default_env reminder
  if [ ! -f "$config_dest" ]; then
    echo '{ "default_env": "" }' > "$config_dest"
    echo "  → session-init-config.json created at ~/.claude/"
  else
    echo "  → session-init-config.json already present, skipping"
  fi

  python3 - "$hook_cmd" <<'EOF'
import json, os, sys

hook_cmd = sys.argv[1]
settings_path = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(settings_path):
    print("  ! ~/.claude/settings.json not found, skipping hook merge", file=sys.stderr)
    sys.exit(0)

with open(settings_path) as f:
    settings = json.load(f)

hook_entry = {
    "matcher": "",
    "hooks": [{"type": "command", "command": hook_cmd}],
}
hooks = settings.setdefault("hooks", {})
existing = hooks.get("SessionStart", [])

if not any("hook-startup" in str(h) for h in existing):
    # Remove any stale session-init.py entries while we're here
    existing = [h for h in existing if "session-init" not in str(h)]
    existing.append(hook_entry)
    hooks["SessionStart"] = existing
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("  → SessionStart hook added to ~/.claude/settings.json")
else:
    print("  → SessionStart hook already present, skipping")
EOF
}

[ "${1:-}" = "" ] && usage

case "$1" in
  push)
    echo "Syncing external skills"
    sync_external_skills
    echo "Deploying skills/ → $SKILLS_DEST"
    for skill_dir in "$SKILLS_SRC"/*/; do
      name=$(basename "$skill_dir")
      echo "  → $name"
      mkdir -p "$SKILLS_DEST/$name"
      cp -r "$skill_dir/." "$SKILLS_DEST/$name/"
    done
    echo "Deploying agents/ → $AGENTS_DEST"
    mkdir -p "$AGENTS_DEST"
    for agent_file in "$AGENTS_SRC"/*.md; do
      [ -f "$agent_file" ] || continue
      name=$(basename "$agent_file")
      echo "  → $name"
      cp "$agent_file" "$AGENTS_DEST/$name"
    done
    install_startup_hook
    echo "Done."
    ;;
  pull)
    echo "Pulling $SKILLS_DEST → skills/"
    for skill_dir in "$SKILLS_DEST"/*/; do
      name=$(basename "$skill_dir")
      echo "  ← $name"
      mkdir -p "$SKILLS_SRC/$name"
      cp -r "$skill_dir/." "$SKILLS_SRC/$name/"
    done
    echo "Pulling $AGENTS_DEST → agents/"
    mkdir -p "$AGENTS_SRC"
    for agent_file in "$AGENTS_DEST"/*.md; do
      [ -f "$agent_file" ] || continue
      name=$(basename "$agent_file")
      echo "  ← $name"
      cp "$agent_file" "$AGENTS_SRC/$name"
    done
    echo "Done. Review changes with: git diff skills/ agents/"
    ;;
  *)
    usage
    ;;
esac
