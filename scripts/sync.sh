#!/usr/bin/env bash
# Sync skills between this repo and ~/.claude/skills/
#
# Usage:
#   ./scripts/sync.sh push   — deploy skills/ → ~/.claude/skills/; update README
#   ./scripts/sync.sh pull   — pull ~/.claude/skills/ → skills/

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DEST="$HOME/.claude/skills"
README="$REPO_DIR/README.md"

usage() {
  echo "Usage: $0 [push|pull]"
  echo "  push  Deploy skills + session-init from repo to ~/.claude/; update README skills table"
  echo "  pull  Pull skills from ~/.claude/skills/ into repo"
  exit 1
}

install_session_init() {
  local script_src="$REPO_DIR/scripts/session-init.py"
  local script_dest="$HOME/.claude/session-init.py"
  local config_dest="$HOME/.claude/session-init-config.json"

  cp "$script_src" "$script_dest"
  echo "  → session-init.py installed to ~/.claude/"

  # Create machine-level config template if absent
  if [ ! -f "$config_dest" ]; then
    echo '{ "default_env": "" }' > "$config_dest"
    echo "  → session-init-config.json created at ~/.claude/ (edit to set machine default env)"
  else
    echo "  → session-init-config.json already present, skipping"
  fi

  python3 - <<'EOF'
import json, os, sys

settings_path = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(settings_path):
    print("  ! ~/.claude/settings.json not found, skipping hook merge", file=sys.stderr)
    sys.exit(0)

with open(settings_path) as f:
    settings = json.load(f)

hook = {"type": "command", "command": "python3 ~/.claude/session-init.py"}
hooks = settings.setdefault("hooks", {})
existing = hooks.get("SessionStart", [])

if not any("session-init" in str(h) for h in existing):
    existing.append(hook)
    hooks["SessionStart"] = existing
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("  → SessionStart hook added to ~/.claude/settings.json")
else:
    print("  → SessionStart hook already present, skipping")
EOF
}

# Regenerate the skills table in README.md from skills/*/SKILL.md frontmatter.
update_readme() {
  local table
  table="| Skill | Command | Purpose |"$'\n'"$(printf '|---|---|---|\n')"
  for skill_dir in $(ls -d "$SKILLS_SRC"/*/ | sort); do
    local skill_md="$skill_dir/SKILL.md"
    [ -f "$skill_md" ] || continue
    local name desc first_sentence
    name=$(grep '^name:' "$skill_md" | head -1 | sed 's/^name:[[:space:]]*//')
    desc=$(grep '^description:' "$skill_md" | head -1 | sed 's/^description:[[:space:]]*//')
    first_sentence=$(echo "$desc" | sed 's/\. .*//')
    table="$table"$'\n'"| **$name** | \`/$name\` | $first_sentence |"
  done

  # Replace everything between "## Skills" and the next "##" heading.
  awk -v new_table="$table" '
    /^## Skills$/ { print; print ""; print new_table; print ""; in_section=1; next }
    in_section && /^## / { in_section=0 }
    !in_section { print }
  ' "$README" > "$README.tmp" && mv "$README.tmp" "$README"

  echo "  README.md skills table updated."
}

[ "${1:-}" = "" ] && usage

case "$1" in
  push)
    echo "Deploying skills/ → $SKILLS_DEST"
    for skill_dir in "$SKILLS_SRC"/*/; do
      name=$(basename "$skill_dir")
      echo "  → $name"
      mkdir -p "$SKILLS_DEST/$name"
      cp -r "$skill_dir/." "$SKILLS_DEST/$name/"
    done
    echo "Installing session-init hook"
    install_session_init
    update_readme
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
    echo "Done. Review changes with: git diff skills/"
    ;;
  *)
    usage
    ;;
esac
