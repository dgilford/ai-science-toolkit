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
| `lit-review` | `/lit-review` | Search and synthesize scientific literature across Zotero, arxiv, bioRxiv, Google Scholar, Consensus |
| `write-new-skill` | `/write-new-skill` | Scaffold and iterate on new Claude Code skills |

## Skill file format

Each skill lives at `~/.claude/skills/<name>/SKILL.md` with YAML frontmatter:

```yaml
---
name: skill-name
description: shown to Claude for auto-invocation matching
allowed-tools: Bash Read Write Edit
---
```

Shell commands in ` ```! ` blocks run before Claude sees the skill content — use for injecting live repo state (git status, log, diff).

## Session workflow

These skills form a session lifecycle:
- **Start**: `/resume` — loads handoff, reports state, recommends next action
- **End**: `/handoff` — writes `.ai/HANDOFF.md`, then runs `update-claude-md`
- **Anytime**: `/update-claude-md` — standalone CLAUDE.md update
- **Planning**: `/grill-me` — stress-test a design before implementing

The `.ai/` directory is repo-local and is gitignored.

## Syncing skills

Skills in `skills/` are the source of truth. Use `scripts/sync.sh` — do not use `cp -r` directly (it creates nested directories when the destination already exists).

```bash
bash scripts/sync.sh push   # deploy skills/ → ~/.claude/skills/; auto-updates README skills table
bash scripts/sync.sh pull   # pull ~/.claude/skills/ → skills/
```

`push` regenerates the `## Skills` table in `README.md` from each skill's `name` and `description` frontmatter (first sentence). The awk replacement targets the block between `## Skills` and the next `##` heading — if that heading is ever missing from README.md, the table update silently no-ops.

After `pull`, review `git diff skills/` — pull brings in all globally installed skills, including any not yet tracked in this repo.
