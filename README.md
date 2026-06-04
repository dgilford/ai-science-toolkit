# ai-tools

Global Claude Code skills for scientific computing workflows.

## Skills

| Skill | Command | Purpose |
|---|---|---|
| **figure-review** | `/figure-review` | Audit a scientific figure for publication-readiness: colormaps, uncertainty, axis labels, caption completeness, and claim support |
| **grill-me** | `/grill-me` | Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree |
| **handoff** | `/handoff` | Create or update a durable project handoff for the next AI agent/session |
| **lit-review** | `/lit-review` | Search and synthesize scientific literature from Zotero, arxiv, bioRxiv, Google Scholar, and Consensus |
| **overbaked** | `/overbaked` | Audit a document, plan, or code for over-engineering, verbosity, and scope creep |
| **resume** | `/resume` | Resume work from repo-local handoff state |
| **reviewer-2** | `/reviewer-2` | Adopt a critical-reviewer stance to stress-test a claim, result, or manuscript section |
| **slack-message** | `/slack-message` | Draft an internal Slack message grounded in current project context and recent workflow |
| **tab-setup** | `/tab-setup` | Assign a unique high-contrast color and name to the current Claude Code session |
| **unstale** | `/unstale` | Detect and repair staleness residue from AI-assisted development — dead imports, resolved TODOs, stale comments/filepaths, and HANDOFF blockers |
| **update-claude-md** | `/update-claude-md` | Update CLAUDE.md with durable knowledge from the current session |
| **write-new-skill** | `/write-new-skill` | Create new Claude Code skills with proper structure and progressive disclosure |

## Installation

Clone the repo and deploy all skills and hooks:

```bash
git clone https://github.com/dgilford/ai-tools.git ~/ai-tools
cd ~/ai-tools
bash scripts/sync.sh push
```

`push` installs skills to `~/.claude/skills/` and registers the `tab-setup` boot hook (see below).

## Session auto-naming and color

Every new Claude Code session is automatically named and color-coded at boot via the `tab-setup` skill's `SessionStart` hook (`hook-startup.sh`). The skill is self-contained and sourced from [dgilford/tab-setup](https://github.com/dgilford/tab-setup).

- **Name**: Haiku generates a logical 2-word adjective-noun name from the project directory name (e.g., `fiscal-ledger` for a finance project). Falls back to a deterministic wordlist hash if the API is unavailable.
- **Color**: Picks the next color not already in use by another running Claude session. Persists through `/clear` and `claude -c`.

**Context reminders at startup:**
- `[resume]` — if `.ai/HANDOFF.md` exists in the project, surfaces the objective and first next action so you know where you left off without running `/resume`
- `[env]` — reminds you to activate the project environment. Detection order:
  1. `pixi.toml` in project → `run: pixi shell`
  2. `environment.yml` in project → `activate: conda <name>`
  3. `.python-version` in project → shows Python version
  4. `.claude-session` in project → explicit override (e.g., `conda: my-env`)
  5. `~/.claude/session-init-config.json` → machine-level default (see below)

**Machine-level environment default (e.g., Jupyter server):**

After `sync.sh push`, a template config is created at `~/.claude/session-init-config.json`. Edit it to set a default env reminder for every session on that machine:

```json
{ "default_env": "pixi shell" }
```

Leave `default_env` empty (`""`) to disable the machine-level reminder.

**Requirements:**
- Claude Code v2.1.152+
- Python 3 (pre-installed on macOS/Linux)
- `ANTHROPIC_API_KEY` in `~/.claude/settings.json` `env` block (optional — falls back to wordlist hash if absent)

**Uninstall:**
```bash
python3 -c "
import json, os
p = os.path.expanduser('~/.claude/settings.json')
s = json.load(open(p))
s.get('hooks', {}).pop('SessionStart', None)
json.dump(s, open(p, 'w'), indent=2)
"
rm ~/.claude/session-init-config.json
```

## Syncing skills

Skills in `skills/` are the source of truth.

```bash
bash scripts/sync.sh push   # deploy skills/ → ~/.claude/skills/
bash scripts/sync.sh pull   # pull ~/.claude/skills/ → skills/
```

After `pull`, review `git diff skills/` — pull brings in all globally installed skills, including any not yet tracked here.

## Session workflow

```
/resume          # start of session — loads handoff, reports state
/handoff         # end of session — writes handoff, updates CLAUDE.md
/update-claude-md  # anytime — promote new knowledge to CLAUDE.md
```

The `.ai/` directory is repo-local (gitignored) and holds session state. Add it to `.gitignore` in any project where you use these skills.

## License

Copyright (c) 2026 Daniel Gilford

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details. You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software, with attribution.
