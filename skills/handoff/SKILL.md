---
name: handoff
description: Create or update a durable project handoff for the next AI agent/session. Use when ending a coding/research session, switching agents, compressing context, or preparing another Claude/ChatGPT/Codex session to continue the work.
allowed-tools: Bash Read Write Edit
disable-model-invocation: true
catalog:
  order: 10
  summary: 'Create or update a durable project handoff (`.ai/HANDOFF.md`) for the next AI agent/session.'
---

Create or update `.ai/HANDOFF.md` so the next agent can resume without rereading this conversation.

## Current repo state

```!
git status --short 2>/dev/null || echo "(not a git repo)"
```

```!
git log --oneline -12 2>/dev/null || echo "(no git log)"
```

```!
git diff --stat HEAD 2>/dev/null | head -30 || echo "(no diff)"
```

## Before writing

Read these if they exist: `.ai/HANDOFF.md`, `CLAUDE.md`, `AGENTS.md`. Scan recently modified files for TODO/FIXME markers. Do not invent results for commands that were not run.

Do not duplicate content already captured in durable artifacts (specs, plans, ADRs, issues, commits, diffs, CLAUDE.md). Reference them by path or URL and summarize only what the next agent needs to act. Redact anything sensitive — API keys, tokens, passwords, PII — even though `.ai/` is gitignored.

## Write `.ai/HANDOFF.md`

Create `.ai/` if missing. Append `.ai/` to `.gitignore` if not already present.

Use only the sections that have real content. Skip empty ones.

## Objective
<!-- one sentence -->

## Next actions
<!-- numbered, concrete, specific — most important section; each action must be immediately executable without a follow-up question. Where a skill or subagent is the right tool, name it in the action itself (e.g. `/grilling` before a state-changing step; the stats-reviewer subagent once the estimator is drafted); point at `/pathfinder` if the next agent won't know which to reach for. -->

<!-- **Good**: `Run scripts/validate.py --baseline 1991-2020 and check the NaN count in coastal cells` -->
<!-- **Good**: `Run /grilling on the resampling design before editing pipeline.py` -->
<!-- **Bad**: `Continue working on the validation` -->

## State
<!-- branch, environment, anything non-obvious; files changed and why -->

## Decisions
<!-- non-obvious choices made this session: what, why, what was rejected -->

## Scientific context
<!-- datasets, versions, paths, provenance; baselines and reference periods;
     counterfactual definitions; methodological assumptions;
     known data issues: NaNs, masking, coordinate alignment, scaling -->

## Pitfalls
<!-- what already went wrong, or is likely to -->

## Open questions
<!-- only if genuinely unresolved and consequential: the question,
     what breaks if answered differently, best current recommendation -->

Preserve useful prior content. Remove stale or superseded details. Distinguish facts, assumptions, and recommendations explicitly.

Ask me at most one question, only if it would materially improve the handoff.

## Ship a worklog entry

After `.ai/HANDOFF.md` is written, run the `worklog` skill to capture this session
to its three targets (local `.ai/` mirror, remote server cache, Notion weekly
page). Pass it the session summary and next actions you wrote above so it does not
re-derive them. `worklog` is best-effort by design — it must never block or fail
the handoff.

## Finally

Run the `evolve-claude-md` skill to promote any durable session knowledge into `CLAUDE.md`.
