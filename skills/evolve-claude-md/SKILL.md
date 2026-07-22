---
name: evolve-claude-md
description: Update CLAUDE.md — or the canonical AGENTS.md it redirects to — with durable knowledge from the current session. Use at the end of a working session to promote new findings, renamed variables, refined definitions, or corrected assumptions into the permanent project record.
allowed-tools: Bash Read Edit
catalog:
  order: 30
  summary: 'Update CLAUDE.md — or the canonical AGENTS.md it redirects to — with durable knowledge from the current session.'
---

Review the current session and update the project's canonical agent-guidance file with anything durable that it doesn't yet know.

## Target file

`CLAUDE.md` by default — but some repos keep a thin `CLAUDE.md` stub that redirects to a canonical `AGENTS.md` (the cross-tool convention scaffolded by `/repo-init`). Resolve the target before editing:

A **redirect stub** is a `CLAUDE.md` whose only content is the redirect to AGENTS.md plus pointer lines (the shape `/repo-init` scaffolds) — nothing project-specific. A stray substantive line in an otherwise-stub file is *residue*: migrate it into `AGENTS.md` as part of this run and leave the stub clean.

| Repo state | Edit |
|---|---|
| `CLAUDE.md` substantive, no `AGENTS.md` (the most common state) | `CLAUDE.md` |
| `CLAUDE.md` is a redirect stub | `AGENTS.md` — leave the stub untouched (create `AGENTS.md` if the stub points at a missing file) |
| No `CLAUDE.md`, but `AGENTS.md` exists | `AGENTS.md` |
| Both exist with substantive content | `CLAUDE.md`, and flag the split-brain to the user so they can consolidate |
| Neither exists | Create `CLAUDE.md` |

## What belongs in the canonical file

Promote only knowledge that is:
- **Permanent** — true beyond this session (not current task state)
- **Project-level** — relevant to anyone working in this repo
- **Non-obvious** — not derivable from reading the code directly

Good candidates: renamed or new variables, corrected definitions, newly understood warn patterns, confirmed pipeline behavior, resolved ambiguities about data schema, architectural decisions with non-obvious rationale.

**Good**: `Pipeline requires --baseline to be passed explicitly; there is no default.` — permanent code behavior that would surprise any future developer.

**Bad**: `Dataset coverage is 1981-09-01 through 2026-05-16 (16,329 zarrs).` — describes the current data artifact being processed, not the codebase. Belongs in HANDOFF.md.

The test: if removing this fact would cause a future developer to misunderstand how the pipeline works, it belongs here. If it describes the data being processed this session, it belongs in the handoff.

Do not add: session-specific state, task progress, anything already in CLAUDE.md, speculative findings, or things that belong in HANDOFF.md.

## Steps

1. Resolve the target file (table above) and read it in full.
2. Scan the session for new knowledge: check git diff, recently modified files, and conversation context.
3. Identify specific additions or corrections — be precise about what changed and why.
4. If nothing meaningful warrants an update, say so explicitly and stop.
5. Otherwise, make targeted edits to the target file. Do not rewrite sections that don't need changing.
6. Briefly summarize what was added or corrected, where, and why.
