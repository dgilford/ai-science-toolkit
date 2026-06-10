---
name: write-new-skill
description: Create new Claude Code skills with proper structure and progressive disclosure. Use when user wants to create, write, or build a new skill.
---

# Writing Skills

## Process

1. **Gather requirements** - ask user about:
   - What task/domain does the skill cover?
   - What specific use cases should it handle?
   - Does it need executable scripts or just instructions?
   - Any reference materials to include?

2. **Draft the skill** - create:
   - SKILL.md with concise instructions
   - Additional reference files if content exceeds 100 lines
   - Utility scripts if deterministic operations needed

3. **Review with user** - present draft and ask:
   - Does this cover your use cases?
   - Anything missing or unclear?
   - Should any section be more/less detailed?

## Skill Structure

```
skill-name/
├── SKILL.md           # Main instructions (required)
├── REFERENCE.md       # Detailed docs (if needed)
└── scripts/           # Utility scripts (if needed)
```

## SKILL.md Template

Frontmatter fields: `name`, `description`, `allowed-tools`. Body: opening directive, optional live state injection, instructions, output template.

Optional sections: `## Anti-Rationalization` (3–5 skill-specific rows: an excuse an agent uses to skip a key step, paired with a factual rebuttal — never generic filler) and `## Verification` (exit-criteria checklist requiring observable evidence before claiming done).

## Shell injection

To inject live state before Claude sees the skill, open a fenced code block with three backticks immediately followed by `!` (no space). The command output replaces the block at skill load time. Always add `|| echo "(fallback)"` for non-git repos.

Use for: git status, git log, git diff, environment checks — any context that must be current rather than recalled.

## Description requirements

The description is what Claude scans to decide whether to auto-invoke the skill.

**Format**: Max 1024 chars. First sentence: what it does. Second: "Use when [specific triggers]."

**Good**: `Create or update a durable project handoff. Use when ending a session, switching agents, or preparing context for the next Claude session.`

**Bad**: `Helps with project state.`

## When to split files

Split into separate files when SKILL.md exceeds 100 lines or content has clearly distinct domains. Keep the split shallow — one level of references only.

## Review checklist

- [ ] Description includes specific triggers ("Use when...")
- [ ] SKILL.md under 100 lines
- [ ] Shell injection added if skill needs live repo or git state
- [ ] Output template uses `<!-- comment -->` not placeholder prose, to distinguish instructions from content
- [ ] Skill handles missing files gracefully (no `.ai/`, no `CLAUDE.md`, not a git repo)
- [ ] Scientific context section included if skill touches data, methods, or analysis
- [ ] Facts, assumptions, and recommendations are distinguished where relevant
- [ ] No time-sensitive information hardcoded
- [ ] Anti-Rationalization table present if skill has skip-worthy judgment steps (3–5 rows, skill-specific, not generic)
- [ ] Verification checklist present if skill has a completion state requiring observable evidence
