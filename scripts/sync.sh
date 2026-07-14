#!/usr/bin/env bash
# Sync skills and agents between this repo and ~/.claude/
#
# Usage:
#   ./scripts/sync.sh push   — deploy skills/ → ~/.claude/skills/; agents/ → ~/.claude/agents/
#   ./scripts/sync.sh pull   — pull ~/.claude/skills/ → skills/; ~/.claude/agents/ → agents/
#   ./scripts/sync.sh lint   — lint skill + agent frontmatter + skill refs (used by CI)
#
# Machine-local exclusions: list skill dir names (one per line) in
# ~/.claude/sync-skills-exclude to skip them during `push` on this machine only.

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

# Machine-local push exclusions. Names (one skill dir per line, # comments ok)
# listed in ~/.claude/sync-skills-exclude are skipped by `push` on THIS machine
# only — the file is not tracked in the repo, so the choice stays machine-local.
EXCLUDE_FILE="$HOME/.claude/sync-skills-exclude"

is_excluded() {
  [ -f "$EXCLUDE_FILE" ] || return 1
  local name="$1" line
  while IFS= read -r line; do
    line="${line%%#*}"                       # strip comments
    line="$(echo "$line" | tr -d '[:space:]')"
    [ -n "$line" ] && [ "$line" = "$name" ] && return 0
  done < "$EXCLUDE_FILE"
  return 1
}

usage() {
  echo "Usage: $0 [push|pull|lint]"
  echo "  push  Deploy skills from repo to ~/.claude/skills/ and agents to ~/.claude/agents/"
  echo "  pull  Pull skills from ~/.claude/skills/ into repo"
  echo "  lint  Lint skill + agent frontmatter and intra-repo skill references only"
  exit 1
}

sync_external_skills() {
  for entry in "${EXTERNAL_SKILLS[@]}"; do
    local repo="${entry%%:*}"
    local dest="${entry##*:}"
    local dest_path="$REPO_DIR/$dest"
    if [ -d "$dest_path/.git" ]; then
      echo "  ↻ $repo (pull)"
      local before after
      before=$(git -C "$dest_path" rev-parse HEAD)
      git -C "$dest_path" pull --ff-only --quiet
      after=$(git -C "$dest_path" rev-parse HEAD)
      # Review gate: fetched scripts become a SessionStart hook, so never deploy
      # unseen upstream changes. Show what changed and require explicit consent
      # (SYNC_EXTERNAL_ACCEPT=1 for non-interactive runs).
      if [ "$before" != "$after" ]; then
        echo "  ! $repo changed since last sync:"
        git -C "$dest_path" log --oneline "$before..$after" | sed 's/^/      /'
        git -C "$dest_path" diff --stat "$before" "$after" -- scripts/ vscode-extension/ | sed 's/^/      /'
        if [ "${SYNC_EXTERNAL_ACCEPT:-0}" != "1" ]; then
          printf "  Deploy these upstream changes? [y/N] "
          read -r reply
          if [ "$reply" != "y" ] && [ "$reply" != "Y" ]; then
            echo "  ✗ declined — rolling back to $before (re-run to review again)"
            git -C "$dest_path" reset --hard --quiet "$before"
            continue
          fi
        fi
      fi
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

# Validate that every agent's and skill's YAML frontmatter parses and has a
# name, and that descriptions stay under the selection-context cap.
# Catches the silent-drop failure mode where a malformed .md deploys fine but
# the agent/skill never registers (e.g. an unquoted multi-line description
# containing a ": " colon-space, which YAML reads as a stray mapping key).
# Aborts the push so the breakage surfaces here, not later.
lint_frontmatter() {
  python3 - "$AGENTS_SRC" "$SKILLS_SRC" <<'EOF'
import glob, os, re, sys
agents_dir, skills_dir = sys.argv[1], sys.argv[2]
try:
    import yaml
except ImportError:
    print("  ! PyYAML not installed — skipping frontmatter lint", file=sys.stderr)
    sys.exit(0)

targets = sorted(glob.glob(os.path.join(agents_dir, "*.md")))
targets += sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md")))

DESC_CAP = 1536  # description chars kept in the model's selection context

failures = []
for path in targets:
    fn = os.path.relpath(path, os.path.dirname(agents_dir))
    text = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        failures.append(f"{fn}: no YAML frontmatter block")
        continue
    try:
        data = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        msg = str(e).splitlines()[0]
        failures.append(f"{fn}: frontmatter does not parse ({msg})")
        continue
    if not isinstance(data, dict) or not data.get("name"):
        failures.append(f"{fn}: frontmatter missing required 'name' field")
        continue
    desc = data.get("description") or ""
    if len(desc) > DESC_CAP:
        failures.append(f"{fn}: description is {len(desc)} chars (cap {DESC_CAP})")

if failures:
    print("  ✗ frontmatter lint failed:", file=sys.stderr)
    for f in failures:
        print(f"      {f}", file=sys.stderr)
    print("    Fix: quote multi-line descriptions, e.g. description: '...'", file=sys.stderr)
    sys.exit(1)
print(f"  ✓ frontmatter lint passed ({len(targets)} files)")
EOF
}

# Verify every backticked `/slash-command` in a skill or agent body resolves to
# a real skill in skills/ (or a known Claude Code built-in / delegated command).
# Catches a launcher whose target was renamed or deleted — e.g. grill-me's body
# is just "Run a `/grilling` session.", so if `grilling` vanished the launcher
# would deploy fine and silently no-op. Frontmatter lint can't see this.
lint_skill_refs() {
  python3 - "$SKILLS_SRC" "$AGENTS_SRC" <<'EOF'
import glob, os, re, sys
skills_dir, agents_dir = sys.argv[1], sys.argv[2]

known = {os.path.basename(os.path.dirname(p))
         for p in glob.glob(os.path.join(skills_dir, "*", "SKILL.md"))}

# Slash commands that are NOT skills in this repo and so are legitimate to
# reference: Claude Code built-ins plus the external review commands ai-review
# delegates to. Add to this set when a body starts citing a new built-in.
BUILTINS = {
    "code-review", "security-review",
    "rename", "color", "clear", "compact", "model", "effort", "review",
    "help", "cost", "fast", "memory",
}

REF = re.compile(r"`/([a-z][a-z0-9-]+)`")
targets = sorted(glob.glob(os.path.join(skills_dir, "*", "SKILL.md")))
targets += sorted(glob.glob(os.path.join(agents_dir, "*.md")))

failures = []
for path in targets:
    fn = os.path.relpath(path, os.path.dirname(skills_dir))
    for name in sorted(set(REF.findall(open(path).read()))):
        if name not in known and name not in BUILTINS:
            failures.append(f"{fn}: references `/{name}`, neither a skill in skills/ nor a known built-in")

if failures:
    print("  ✗ skill-reference lint failed:", file=sys.stderr)
    for f in failures:
        print(f"      {f}", file=sys.stderr)
    print("    Fix: correct the reference, add the missing skill, or allowlist a new built-in in lint_skill_refs().", file=sys.stderr)
    sys.exit(1)
print(f"  ✓ skill-reference lint passed ({len(targets)} files)")
EOF
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

install_statusline() {
  # Deploy the status-line command script and ensure settings.json references it.
  # Reconciles the statusLine block to settings/settings.json on every push, so
  # footer config changes propagate (a non-destructive merge silently skipped them).
  local script_src="$REPO_DIR/settings/statusline-command.sh"
  local script_dest="$HOME/.claude/statusline-command.sh"

  if [ ! -f "$script_src" ]; then
    echo "  ! settings/statusline-command.sh not found, skipping status line"
    return 0
  fi
  cp "$script_src" "$script_dest"
  chmod +x "$script_dest"
  echo "  → statusline-command.sh deployed to ~/.claude/"

  REPO_DIR="$REPO_DIR" python3 - <<'EOF'
import json, os
settings_path = os.path.expanduser("~/.claude/settings.json")
if not os.path.exists(settings_path):
    print("  ! ~/.claude/settings.json not found, skipping statusLine merge")
    raise SystemExit(0)

# Canonical statusLine block lives in the repo's settings/settings.json.
repo_settings = os.path.join(os.environ["REPO_DIR"], "settings", "settings.json")
with open(repo_settings) as f:
    desired = json.load(f)["statusLine"]

with open(settings_path) as f:
    settings = json.load(f)

if settings.get("statusLine") == desired:
    print("  → statusLine already up to date, skipping")
else:
    settings["statusLine"] = desired
    with open(settings_path, "w") as f:
        json.dump(settings, f, indent=2)
        f.write("\n")
    print("  → statusLine block reconciled in ~/.claude/settings.json")
EOF
}

[ "${1:-}" = "" ] && usage

case "$1" in
  push)
    echo "Syncing external skills"
    sync_external_skills
    echo "Linting skill + agent frontmatter"
    lint_frontmatter
    lint_skill_refs
    echo "Deploying skills/ → $SKILLS_DEST"
    for skill_dir in "$SKILLS_SRC"/*/; do
      name=$(basename "$skill_dir")
      if is_excluded "$name"; then
        echo "  ⤫ $name (excluded on this machine via $EXCLUDE_FILE)"
        continue
      fi
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
    install_statusline
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
  lint)
    lint_frontmatter
    lint_skill_refs
    ;;
  *)
    usage
    ;;
esac
