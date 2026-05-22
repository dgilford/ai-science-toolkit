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

Skills in `skills/` are the source of truth. To deploy to the global install:

```bash
cp -r skills/<name> ~/.claude/skills/
```

To pull the current global state back into the repo:

```bash
cp -r ~/.claude/skills/<name> skills/
```

When adding a new skill, do both: write it in `skills/`, then copy to `~/.claude/skills/`.
