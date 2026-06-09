# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This directory is a workspace for developing and iterating on global Claude Code skills. Skills are installed at `~/.claude/skills/<name>/SKILL.md` and are available across all projects.

## Installed skills

| Skill | Trigger | Purpose |
|---|---|---|
| `handoff` | `/handoff` | Write `.ai/HANDOFF.md` + run `update-claude-md` at session end |
| `resume` | `/resume` | Reconstruct session context from `.ai/HANDOFF.md` at session start |
| `update-claude-md` | `/update-claude-md` | Promote durable session knowledge into `CLAUDE.md` |
| `grill-me` | `/grill-me` | Stress-test a plan via relentless structured questioning |
| `lit-review` | `/lit-review` | Search and synthesize scientific literature across Zotero, arxiv, bioRxiv, Google Scholar, Consensus. Requires `ZOTERO_USER_ID`, `ZOTERO_API_KEY`, `ZOTERO_INBOX_COLLECTION` in `~/.claude/settings.json` env block for Zotero write support. |
| `overbaked` | `/overbaked` | Audit a document, plan, or code for over-engineering, verbosity, and scope creep |
| `slack-message` | `/slack-message` | Draft a first-draft internal Slack message grounded in live git context |
| `write-new-skill` | `/write-new-skill` | Scaffold and iterate on new Claude Code skills |
| `unstale` | `/unstale` | Detect and repair staleness residue from AI-assisted dev (dead imports, resolved TODOs, stale comments/filepaths); `--auto` applies HIGH-confidence fixes |
| `figure-review` | `/figure-review` | Per-criterion publication-readiness audit for scientific figures (colormap, uncertainty, axes, caption, claim support); `--style` adds CC house style |
| `reviewer-2` | `/reviewer-2` | Adversarial per-claim stress-test (baseline, counterfactual, alternatives, uncertainty consistency); defers citation checks to `/lit-review` |

## Skill file format

Each skill lives at `~/.claude/skills/<name>/SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: shown to Claude for auto-invocation matching
allowed-tools: Bash Read Write Edit
argument-hint: "[--flag | optional arg]"   # shown in user-facing help; optional
---
```

Shell commands in ` ```! ` blocks run before Claude sees the skill content — use for injecting live repo state (git status, log, diff).

Skills may include companion reference files (e.g., `REFERENCE.md`, `CC-STYLE.md`, `COLORBLIND.md`) in the same skill directory. Load them at runtime using the same `!` block syntax above, pointing at the deployed path: `cat ~/.claude/skills/<name>/COMPANION.md 2>/dev/null || echo "(not found)"`. This keeps SKILL.md lean while injecting richer context at load time. Only the deployed path (`~/.claude/skills/`) is referenced — the repo copy in `skills/` is synced there by `sync.sh push`.

## Session workflow

These skills form a session lifecycle:
- **Start**: `/resume` — loads handoff, reports state, recommends next action
- **End**: `/handoff` — writes `.ai/HANDOFF.md`, then runs `update-claude-md`
- **Anytime**: `/update-claude-md` — standalone CLAUDE.md update
- **Planning**: `/grill-me` — stress-test a design before implementing

The `.ai/` directory is repo-local and is gitignored.

## Boot hooks

| Hook | Script | Purpose |
|---|---|---|
| `SessionStart` | `~/.claude/skills/tab-setup/scripts/hook-startup.sh` | Auto-name and color-code each session on boot |

`hook-startup.sh` is part of the `tab-setup` skill (deployed from `dgilford/tab-setup`). It is fully self-contained — no dependency on this repo. It generates a session name via Haiku API (requires `ANTHROPIC_API_KEY` in the `env` block of `~/.claude/settings.json`) with a wordlist fallback, assigns a tab color, and prints `[resume]` / `[env]` reminders to stderr. `sync.sh push` registers it in `~/.claude/settings.json` automatically.

Tab color assignments are persisted in `~/.claude/project-colors.json` (cwd → {color, name, pid}), which is written by `hook-startup.sh` and never touched by the watcher. This drives color persistence through `/clear` (same PID) and `claude -c` (same cwd, dead PID not in use).

## Syncing skills

Skills in `skills/` are the source of truth. Use `scripts/sync.sh` — do not use `cp -r` directly (it creates nested directories when the destination already exists).

```bash
bash scripts/sync.sh push   # deploy skills/ → ~/.claude/skills/; agents/ → ~/.claude/agents/; register hook-startup.sh
bash scripts/sync.sh pull   # pull ~/.claude/skills/ → skills/; ~/.claude/agents/ → agents/
```

After `pull`, review `git diff skills/ agents/` — pull brings in all globally installed skills and agents, including any not yet tracked in this repo.

**Always edit `skills/` (the repo copy), never `~/.claude/skills/` directly.** `push` overwrites the installed copy from the repo — edits to the installed copy are silently lost on the next push.

**External skills** (`tab-setup`) are a special case: `push` pulls from `github.com/dgilford/tab-setup` into `tab-setup/` (a nested git repo at the repo root) *before* copying into `skills/tab-setup/`. Edits to `skills/tab-setup/` are overwritten by this pull. To change tab-setup scripts: edit `tab-setup/scripts/`, commit and push to `dgilford/tab-setup`, then run `sync.sh push`.

## Commits

Global GPG signing is enabled (`commit.gpgsign = true`). In this environment the pinentry GUI times out before the passphrase can be entered. Commits must be made in an external terminal with the GPG key already unlocked, or run directly by the user.
