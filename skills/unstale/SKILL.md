---
name: unstale
description: Detect and optionally repair staleness residue left behind after AI-assisted development — dead imports, resolved TODOs still in code, comments and docstrings describing logic that has since changed, stale filepaths/README instructions, and outdated HANDOFF.md blockers. Use this whenever the user mentions stale code, cleanup after a refactor, "this comment is wrong now," leftover TODOs, doc drift, or wants to tidy a file before a handoff or release — even if they don't say "unstale." Always emits a structured report before making any edit.
allowed-tools: Bash Read Edit
argument-hint: "[--auto]"
---

## Scope

If files are named, scan those. Otherwise, start with recently changed files:

```!
git status --short 2>/dev/null || echo "(not a git repo)"
```

## Modes

- `/unstale` — emit report, no edits.
- `/unstale --auto` — emit report, then apply all HIGH-confidence fixes; append apply log.

## What to scan

- Dead imports (not referenced)
- Resolved TODOs still in code (`# TODO`, `# FIXME`)
- Comments or docstrings that describe logic no longer present in the code
- Stale filepaths or README instructions (verify against the repo tree)
- Resolved blockers still listed in `.ai/HANDOFF.md`

## Confidence tiers

| Tier | Items | `--auto` eligible |
|---|---|---|
| HIGH | Dead imports; resolved TODOs; filepaths verifiable against repo; resolved HANDOFF blockers | yes |
| MED/LOW | Intent comments; planned-feature lists; divergence requiring judgment | never |

## Report (emit before any edit)

One row per finding:

| Item | Location | Category | Confidence | Action |
|---|---|---|---|---|
| `import foo` unused | `utils.py:3` | dead import | HIGH | remove |
| `# using requests not httpx — httpx had auth bug` | `api.py:14` | intent comment | MED | flag only |

## Apply log (`--auto` only)

Append:

```
Applied fixes:
- utils.py:3 — removed unused import `foo`
```

## Does not

- Flag style, quality, or verbosity issues — that is `/overbaked`'s domain.
- Touch MED/LOW items under any flag.
- Infer additional files to scan beyond those named or git-tracked as changed.
