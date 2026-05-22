---
name: update-claude-md
description: Update CLAUDE.md with durable knowledge from the current session. Use at the end of a working session to promote new findings, renamed variables, refined definitions, or corrected assumptions into the permanent project record.
allowed-tools: Bash Read Edit
---

Review the current session and update `CLAUDE.md` with anything durable that it doesn't yet know.

## What belongs in CLAUDE.md

Promote only knowledge that is:
- **Permanent** — true beyond this session (not current task state)
- **Project-level** — relevant to anyone working in this repo
- **Non-obvious** — not derivable from reading the code directly

Good candidates: renamed or new variables, corrected definitions, newly understood warn patterns, confirmed pipeline behavior, resolved ambiguities about data schema, architectural decisions with non-obvious rationale.

Do not add: session-specific state, task progress, anything already in CLAUDE.md, speculative findings, or things that belong in HANDOFF.md.

## Steps

1. Read `CLAUDE.md` in full.
2. Scan the session for new knowledge: check git diff, recently modified files, and conversation context.
3. Identify specific additions or corrections — be precise about what changed and why.
4. If nothing meaningful warrants an update, say so explicitly and stop.
5. Otherwise, make targeted edits to `CLAUDE.md`. Do not rewrite sections that don't need changing.
6. Briefly summarize what was added or corrected and why.
