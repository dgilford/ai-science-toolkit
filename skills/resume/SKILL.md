---
name: resume
description: Resume work from repo-local handoff state. Use when starting a new Claude Code session, switching agents, returning to a project, or asking an AI agent to reconstruct context from prior work.
allowed-tools: Bash Read
---

Resume this project from the repo-local handoff state.

## Current repo state

```!
git status --short 2>/dev/null || echo "(not a git repo)"
```

```!
git log --oneline -12 2>/dev/null || echo "(no git log)"
```

## Instructions

Check for `.ai/HANDOFF.md`. Two paths:

**If found:** Read it, along with `CLAUDE.md` and `AGENTS.md` if present. Then verify it against current repo state: confirm the branch matches, check that referenced files exist, and flag any commits more recent than the handoff that aren't reflected in it.

**If not found:** Tell the user explicitly that no handoff was found before doing anything else. Then reconstruct best-effort from the repo: scan recent git log, read recently modified files, and check for obvious entry points (scripts, notebooks, configs).

## Report

State on the first line whether the handoff was loaded: `Handoff loaded from .ai/HANDOFF.md` or `No handoff found — reconstructed from repo.`

Then open with a 2–3 sentence conversational recap — what this project is, what was being worked on, and where things stand. Write it the way a colleague would catch someone up after they've been away, not as a bullet list.

Then follow with only the sections that have real content:

**Key decisions** — consequential choices already locked in.

**Scientific context** — datasets, baselines, reference periods, counterfactual definitions, known data quality issues.

**Risks** — load-bearing assumptions, things likely to go wrong.

**Next action** — the one concrete thing to do right now. If multiple paths are plausible, compare them in 2–3 lines each and recommend one.
