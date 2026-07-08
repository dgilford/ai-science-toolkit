#!/usr/bin/env bash
# Regenerate the skill/agent catalog tables in CLAUDE.md and README.md from
# skills/*/SKILL.md and agents/*.md frontmatter (the `catalog:` block), so the
# same table can't silently drift between the two files (it has, twice).
#
# Usage:
#   ./scripts/gen-docs.sh write   — regenerate the marked table regions in place
#   ./scripts/gen-docs.sh check   — fail (nonzero exit, diff printed) if the
#                                   committed tables don't match freshly
#                                   generated ones (CI drift gate)
#
# Marked regions look like:
#   <!-- gen-docs:skills:start ... --> ... <!-- gen-docs:skills:end -->
#   <!-- gen-docs:agents:start ... --> ... <!-- gen-docs:agents:end -->
# Only the lines between a start/end pair are replaced; the marker comments
# themselves are preserved untouched.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "Usage: $0 [write|check]"
  exit 1
}

[ "${1:-}" = "" ] && usage

python3 - "$REPO_DIR" "$1" <<'EOF'
import glob, os, re, sys
repo_dir, mode = sys.argv[1], sys.argv[2]
if mode not in ("write", "check"):
    sys.exit(f"Usage: gen-docs.sh [write|check] (got {mode!r})")

try:
    import yaml
except ImportError:
    sys.exit("PyYAML not installed — cannot generate docs")

def load_frontmatter(path):
    text = open(path).read()
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        sys.exit(f"{path}: no YAML frontmatter block")
    return yaml.safe_load(m.group(1)) or {}

# --- Load skills (skills/*/SKILL.md) ---
skills = []
for path in sorted(glob.glob(os.path.join(repo_dir, "skills", "*", "SKILL.md"))):
    fm = load_frontmatter(path)
    cat = fm.get("catalog")
    if not cat:
        continue  # skill opted out of the generated catalog entirely
    skills.append({
        "name": fm["name"],
        "order": cat.get("order"),
        "summary": cat["summary"],
        "repo_url": cat.get("repo_url"),
        "claude_md": cat.get("claude_md", True),
        "provenance": cat.get("provenance"),
    })

# --- Load agents (agents/*.md) ---
agents = []
for path in sorted(glob.glob(os.path.join(repo_dir, "agents", "*.md"))):
    fm = load_frontmatter(path)
    cat = fm.get("catalog")
    if not cat:
        continue
    agents.append({
        "name": fm["name"],
        "order": cat["order"],
        "domain": cat["domain"],
        "reviews_for": cat["reviews_for"],
        "summary": cat["summary"],
    })

def skill_name_cell(s, linked):
    bare = f"`{s['name']}`" if not linked else f"**{s['name']}**"
    if linked and s["repo_url"]:
        return f"**[{s['name']}]({s['repo_url']})**"
    return bare

# Provenance is a structured `catalog.provenance` block (relation/author/url)
# so attribution is derived, not hand-typed into each summary — which is how
# "By" and "Adapted from" drifted apart for the same skill. Omit the block for
# original work (no suffix rendered).
RELATION_VERB = {"authored": "By", "adapted": "Adapted from", "forked": "Forked from"}

def render_summary(s):
    text = s["summary"]
    prov = s.get("provenance")
    if not prov:
        return text
    verb = RELATION_VERB.get(prov.get("relation"))
    if verb is None:
        sys.exit(f"{s['name']}: catalog.provenance.relation must be one of "
                 f"{sorted(RELATION_VERB)}, got {prov.get('relation')!r}")
    author, url = prov.get("author"), prov.get("url")
    if not author:
        sys.exit(f"{s['name']}: catalog.provenance needs an 'author'")
    credit = f"[{author}]({url})" if url else author
    return f"{text} {verb} {credit}."

def gen_skills_table_claude_md():
    rows = sorted((s for s in skills if s["claude_md"]), key=lambda s: s["order"])
    lines = ["| Skill | Trigger | Purpose |", "|---|---|---|"]
    for s in rows:
        lines.append(f"| `{s['name']}` | `/{s['name']}` | {render_summary(s)} |")
    return lines

def gen_skills_table_readme():
    rows = sorted(skills, key=lambda s: s["name"].lower())
    lines = ["| Skill | Command | Purpose |", "|---|---|---|"]
    for s in rows:
        lines.append(f"| {skill_name_cell(s, linked=True)} | `/{s['name']}` | {render_summary(s)} |")
    return lines

def gen_agents_table_claude_md():
    rows = sorted(agents, key=lambda a: a["order"])
    lines = ["| Agent | Domain | Reviews for |", "|---|---|---|"]
    for a in rows:
        lines.append(f"| `{a['name']}` | {a['domain']} | {a['reviews_for']} |")
    return lines

def gen_agents_table_readme():
    rows = sorted(agents, key=lambda a: a["order"])
    lines = ["| Agent | Purpose |", "|---|---|"]
    for a in rows:
        lines.append(f"| **{a['name']}** | {a['summary']} |")
    return lines

GENERATORS = {
    ("CLAUDE.md", "skills"): gen_skills_table_claude_md,
    ("CLAUDE.md", "agents"): gen_agents_table_claude_md,
    ("README.md", "skills"): gen_skills_table_readme,
    ("README.md", "agents"): gen_agents_table_readme,
}

def replace_region(text, region, new_lines, path):
    start_re = re.compile(rf"(<!-- gen-docs:{region}:start[^\n]*-->\n)(.*?)(\n<!-- gen-docs:{region}:end -->)", re.S)
    m = start_re.search(text)
    if not m:
        sys.exit(f"{path}: no gen-docs:{region} marker pair found")
    return text[:m.start()] + m.group(1) + "\n".join(new_lines) + m.group(3) + text[m.end():]

exit_code = 0
for filename in ("CLAUDE.md", "README.md"):
    path = os.path.join(repo_dir, filename)
    original = open(path).read()
    updated = original
    for region in ("skills", "agents"):
        gen = GENERATORS.get((filename, region))
        if gen is None:
            continue
        updated = replace_region(updated, region, gen(), path)
    if updated != original:
        if mode == "check":
            print(f"  ✗ {filename} is out of date with skill/agent catalog frontmatter — run: bash scripts/gen-docs.sh write")
            exit_code = 1
        else:
            with open(path, "w") as f:
                f.write(updated)
            print(f"  → {filename} updated")
    else:
        print(f"  ✓ {filename} already up to date")

sys.exit(exit_code)
EOF
