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
  echo "  push  Deploy skills from repo to ~/.claude/skills/; update README skills table"
  echo "  pull  Pull skills from ~/.claude/skills/ into repo"
  exit 1
}

# Regenerate the skills table in README.md from skills/*/SKILL.md frontmatter.
update_readme() {
  local table_file
  table_file=$(mktemp)
  printf '%s\n%s\n' "| Skill | Command | Purpose |" "|---|---|---|" > "$table_file"
  for skill_dir in $(ls -d "$SKILLS_SRC"/*/ | sort); do
    local skill_md="$skill_dir/SKILL.md"
    [ -f "$skill_md" ] || continue
    local name desc first_sentence
    name=$(grep '^name:' "$skill_md" | head -1 | sed 's/^name:[[:space:]]*//')
    desc=$(grep '^description:' "$skill_md" | head -1 | sed 's/^description:[[:space:]]*//')
    first_sentence=$(echo "$desc" | sed 's/\. .*//')
    printf '| **%s** | `/%s` | %s |\n' "$name" "$name" "$first_sentence" >> "$table_file"
  done

  # Replace everything between "## Skills" and the next "##" heading.
  # Uses Python instead of awk -v because macOS awk doesn't support multiline -v values.
  python3 - "$README" "$table_file" <<'PYEOF'
import sys
readme_path, table_path = sys.argv[1], sys.argv[2]
with open(readme_path) as f:
    lines = f.readlines()
with open(table_path) as f:
    table = f.read()
out, in_section = [], False
for line in lines:
    if line.rstrip() == "## Skills":
        out.append(line)
        out.append("\n")
        out.append(table)
        out.append("\n")
        in_section = True
    elif in_section and line.startswith("## "):
        in_section = False
        out.append(line)
    elif not in_section:
        out.append(line)
with open(readme_path, "w") as f:
    f.writelines(out)
PYEOF
  rm -f "$table_file"
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
