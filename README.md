# ai-tools

Global Claude Code skills and agent personas for scientific computing workflows.

## Agents

Subagent personas live in `agents/` and are deployed to `~/.claude/agents/`. Each adopts a domain-expert reviewer stance — adversarial, ranked concerns, no rewriting.

| Agent | Purpose |
|---|---|
| **attribution-reviewer** | Reviews climate-attribution claims for counterfactual, baseline, framing, uncertainty, model adequacy, and overclaiming |
| **meteo-reviewer** | Reviews weather event analyses and atmospheric mechanism claims for dynamical, physical, observational, and hydrological rigor |
| **stats-reviewer** | Reviews statistical analyses for estimator validity, causal identification, inference under dependence, model specification, multiple testing, and ML validity |
| **scicomm-reviewer** | Reviews public-facing science products for audience specificity, relevance framing, cognitive load, jargon, solutions/benefits, and uncertainty language (COMPASS principles) |

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
| **unstale** | `/unstale` | Detect and repair staleness residue in Python library code and notebooks — dead imports, dead code, resolved TODOs, stale comments/docstrings, and HANDOFF blockers |
| **update-claude-md** | `/update-claude-md` | Update CLAUDE.md with durable knowledge from the current session |
| **write-new-skill** | `/write-new-skill` | Create new Claude Code skills with proper structure and progressive disclosure |

## Installation

Clone the repo and deploy all skills and hooks:

```bash
git clone https://github.com/dgilford/ai-tools.git ~/Projects/ai-tools
cd ~/Projects/ai-tools
bash scripts/sync.sh push
```

`push` installs skills to `~/.claude/skills/` and registers the `tab-setup` boot hook (see below).

## Repository layout

- `AGENTS.md` - Codex entry point. It points Codex at `CLAUDE.md` for shared
  durable repo guidance.
- `CLAUDE.md` - shared source of truth for repository workflow notes,
  skill-development conventions, sync behavior, and session lifecycle.
- `agents/` - source copies of Claude Code subagent personas. Edit here first,
  then deploy with `scripts/sync.sh push` (syncs to `~/.claude/agents/`).
- `skills/` - source copies of Claude Code skills. Edit here first, then deploy
  with `scripts/sync.sh push`.
- `scripts/sync.sh` - pushes `skills/` to `~/.claude/skills/`, syncs the
  external `tab-setup` skill, regenerates the skills table in this README, and
  registers the startup hook.
- `scripts/ai-sessions.sh` - shell function for listing live Claude and Codex
  CLI sessions with resume commands.
- `settings/` - commit-safe global Claude Code settings plus restore notes.
  Machine-local `settings.local.json` backups stay gitignored.
- `tab-setup/` - external skill checkout from `dgilford/tab-setup`; `sync.sh
  push` refreshes this before copying its scripts into `skills/tab-setup/`.
- `vscode-extension/` - small helper extension for applying pending Claude tab
  colors/names in VS Code-compatible remote servers.

## Session auto-naming and color

Every new Claude Code session is automatically named and color-coded at boot via the `tab-setup` skill's `SessionStart` hook (`hook-startup.sh`). The skill is self-contained, originally developed by [JeraldHuff/tab-setup](https://github.com/JeraldHuff/tab-setup) and forked to [dgilford/tab-setup](https://github.com/dgilford/tab-setup).

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

## Listing running sessions (`ai-sessions`)

`scripts/ai-sessions.sh` defines an `ai-sessions` shell function that lists your running Claude/Codex CLI sessions with their resume commands. Source it directly from the repo (no copy — `git pull` keeps it current) by adding to `~/.bashrc` (or `~/.zshrc`):

```bash
source ~/Projects/ai-tools/scripts/ai-sessions.sh
```

Run `ai-sessions` to list sessions. Claude's own recap (`away_summary`) is shown by default for each session.

## Syncing skills and agents

Skills in `skills/` and agents in `agents/` are the source of truth.

```bash
bash scripts/sync.sh push   # deploy skills/ → ~/.claude/skills/; agents/ → ~/.claude/agents/
bash scripts/sync.sh pull   # pull ~/.claude/skills/ → skills/; ~/.claude/agents/ → agents/
```

After `pull`, review `git diff skills/ agents/` — pull brings in all globally installed skills and agents, including any not yet tracked here.

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
