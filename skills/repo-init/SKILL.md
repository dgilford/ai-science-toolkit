---
name: repo-init
description: SLASH COMMAND — type /repo-init to scaffold a new repository (or retrofit an existing one) with a standard project structure. Starts with a short intake grill (--no-grill skips). Research mode by default; --package for a distributable src-layout library. Never overwrites existing files; --dry-run previews.
disable-model-invocation: true
allowed-tools: Bash Read Write Edit
argument-hint: "[path] [--package] [--no-license] [--no-grill] [--dry-run]"
catalog:
  order: 5
  summary: 'Scaffold a new repo (or retrofit an existing one) with a standard structure via a short intake grill: research mode by default, `--package` for a distributable library. Never overwrites; `--dry-run` previews.'
---

Initialize a repository with a standard, opinionated project structure. Run once per project. Re-running (or running on an existing repo) **adds missing pieces only** — it never overwrites or repairs existing files.

**The intake is a hard gate.** Create nothing — no directories, no files, not even `git init` — until the step-2 intake is either completed with the user or skipped by an explicit flag (`--no-grill` / `--dry-run`). Scaffolding first and asking later defeats the skill: the answers determine what gets scaffolded.

## File templates (loaded at runtime)

```!
D="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/repo-init}"; D="${D:-$HOME/.claude/skills/repo-init}"; cat "$D/TEMPLATES.md" 2>/dev/null || echo "(TEMPLATES.md not found — abort and report a broken install)"
```

## Live state

```!
pwd && git rev-parse --show-toplevel 2>/dev/null || echo "(not a git repo yet)"
```

## Modes

| Invocation | Mode | Shape |
|---|---|---|
| `/repo-init` | **research** (default) | Analysis project: notebooks, script-first compute, gitignored data/figures |
| `/repo-init --package` | **package** | Distributable library: src-layout, pyproject, tests, CI, CITATION.cff |
| `[path]` | either | Target directory (default: cwd). Must exist or be creatable. |
| `--no-license` | either | Skip the LICENSE file and the pyproject/CITATION `license` fields. |
| `--no-grill` | either | Skip the intake grill; scaffold with template stubs as-is (LICENSE defaults to MIT with the git author as holder — flagged in the report). |
| `--dry-run` | either | Print the would-be report (every path → created/skipped) for the flag-resolved mode, without writing anything, running `git init`, or grilling. (Since the grill is skipped, decisions it would set — mode flip, license, data guards — are not previewed.) |

## Ground rules

1. **Never destructive.** Before writing any file: if it already exists, skip it — never overwrite, never merge silently. `mkdir -p` for directories is always fine. Report `skipped (exists)`; reserve `skipped (exists — differs from template)` for files that look like a broken or partial scaffold (unfilled placeholders, a template skeleton with no real content). Pre-existing real content is normal, not a warning.
2. **Two sanctioned exceptions to "never touch an existing file":**
   - **`.gitignore`** — never rewrite; diff it against the template entries, report which standard entries are missing, and ask before appending (gitignoring is a deliberate choice). **After any append**, run `git ls-files` against the newly ignored patterns: if matches exist, warn explicitly that `.gitignore` does not untrack already-committed files (they stay in the repo and its history until `git rm --cached` / a history rewrite) — this matters most before a repo ever goes public.
   - **`docs/DECISIONS.md`** — an append-only ledger: a re-run *appends* a new dated init entry recording that run's intake answers; existing entries are never edited or rewritten.
3. **CLAUDE.md / AGENTS.md on retrofit:** if `CLAUDE.md` already exists and is *not* the redirect stub (compare against the CLAUDE-STUB template), do **not** create `AGENTS.md` — ask the user: keep `CLAUDE.md` canonical (scaffold no AGENTS.md, or an inverted 3-line AGENTS.md stub pointing at CLAUDE.md), or migrate to the AGENTS-canonical pattern. Never leave both files substantive — that split-brain is exactly what the redirect convention exists to prevent.
4. Substitute all `{{PLACEHOLDERS}}` and `<angle-bracket>` fills per the header of TEMPLATES.md before writing. `{{AUTHOR}}`/`{{EMAIL}}` come from `git config user.name`/`user.email`; if unset, use a `<fill me in>` placeholder and flag it in the report. If the intake changes the mode, redo step-1 resolution (including `{{PKG_NAME}}`) before scaffolding.

## Steps

1. **Resolve** target dir, provisional mode (from flags), repo name (dir basename), and — package mode — `{{PKG_NAME}}`. State all four before anything else.
2. **Intake grill** — the hard gate (skipped only under `--no-grill` or `--dry-run`): invoke the `grilling` skill on the tree below; if it is not available, ask the questions yourself — the gate stands either way. The tree is **hierarchical — later questions are gated and shaped by earlier answers**. Ask in order, **one at a time, waiting for each answer**. Evidence (dir name, flags, visible files) supplies the *default offered inside the question* — never a silently assumed answer.

   **Answers are the user's words.** Record each answer verbatim in the DECISIONS init entry (quoted; shorten only with a marked ellipsis). Never write an answer the user did not give: an unasked or unanswered question is recorded as `(not asked — <reason>)`, and a skipped intake as `(intake skipped)`. An invented answer is worse than a skipped question — it forges the decision log.

   | # | Question | Asked when | Shaped by earlier answers | Lands in |
   |---|---|---|---|---|
   | 1 | **Purpose** — what is this repo for, and what is the end artifact (paper, report, software release, operational product)? | Always | — | `AGENTS.md` Purpose; `README.md` description; sets the defaults offered in Q2/Q4/Q5 |
   | 2 | **Shape & lifespan** — analysis project or distributable library? One-off or long-lived? | Always (`--package` pre-answers "library") | Q1: software artifact → default library; paper/analysis → default research; operational products start as research mode | Final mode (if this changes it, redo step-1 resolution); operational posture note in `AGENTS.md` |
   | 3 | **Audience & visibility** — private, shared with collaborators, public later (e.g. at publication), or public now? | Always | Q1: a published-paper artifact defaults to "public at publication" | README tone; gates Q3b; reminder to match the GitHub remote's visibility |
   | 3b | **License & ownership** — who owns the copyright: the author personally, or an employer (work-for-hire)? Which license? | Skipped only if Q3 = private **and** the user accepts skipping. An explicit `--no-license` pre-answers the *license* half as "skip" (never re-ask it); if Q3 indicates a public trajectory, still ask the *ownership* half and note the flag in DECISIONS | Q3: any public trajectory makes this required, not optional | `LICENSE` (correct holder via `{{COPYRIGHT_HOLDER}}`); pyproject `license` line (deleted if skipped); `CITATION.cff` |
   | 4 | **Data** — where will input data come from (scripted download, delivered, cloud store)? Anything restricted that must never be committed? Any dependency on an existing repo or its data? | Skipped if Q1+Q2 imply no data (e.g. pure library) | Q3: restricted data + a future-public answer → strongest warning; on retrofit, triggers the ground-rule-2 tracked-file check immediately | `data/README.md` provenance seeds; extra `.gitignore` guards; repo dependencies documented in `AGENTS.md` |
   | 5 | **Reproducibility bar** — will anyone (future-you, a coauthor, a reviewer) need to rerun this after the project goes cold? | Skipped if Q4 was skipped and Q1 has no analysis component | Q3/Q4: public visibility or non-scripted data raise the suggested default | Recorded in `docs/DECISIONS.md`; if the bar is high, next-steps suggests pinning an environment (environment setup is out of scope for init) |

   **Every answer is recorded, dated and attributed, in the `docs/DECISIONS.md` init entry** (see DECISIONS template) — day-zero answers drift, and the log is what lets a future session tell current truth from initial guess.

3. **git init** if not already a repository.
4. **Scaffold** per mode:

   **Common core (both modes):** `.gitignore` (CORE + mode section) · `.ai/` dir · `CLAUDE.md` (thin stub) · `AGENTS.md` (subject to ground rule 3 on retrofit) · `README.md` · `docs/DECISIONS.md` (append the init entry if it already exists) · `LICENSE` (per Q3b; skipped under `--no-license`).

   **Research mode:** `notebooks/` + README · `scripts/` + README · `data/inputs/` + `data/outputs/` + `data/README.md` · `figures/` + README.

   **Package mode:** `src/{{PKG_NAME}}/__init__.py` · `tests/test_import.py` · `pyproject.toml` · `.pre-commit-config.yaml` · `.github/workflows/pytest.yaml` · `CITATION.cff`. Adapt the AGENTS.md Layout table and data rule to what was actually created.

5. **Report** a table: every path → `created` / `skipped (exists)` / `skipped (exists — differs from template)` / `appended (.gitignore, with approval)`. Flag unfilled placeholders and any tracked files matching newly ignored patterns (ground rule 2).
6. **Suggest next steps** (do not execute unasked): fill in anything the report flagged; `pre-commit install && pre-commit autoupdate` (package mode); pin an environment if the Q5 bar was high; first commit; connect a Zenodo webhook before the first release (package mode).

## Anti-Rationalization

| Excuse | Reality |
|---|---|
| "The directory is empty — there's nothing to ask about" | An empty dir is exactly when the answers exist only in the user's head. Ask. |
| "I can infer sensible defaults from context" | Inference supplies the *offered default*; only the user supplies the answer. Proceeding on assumed defaults is a skipped intake, not a fast one. |
| "The user seems in a hurry" | Speed has a flag: `--no-grill`. Only the user invokes it. |
| "I'll scaffold now and confirm afterwards" | The answers change what gets scaffolded (mode, license, data guards). Afterwards is too late. |
| "The user's answer was vague — I'll write what they meant" | Record their words verbatim and ask a follow-up if too vague to act on. An invented answer forges the decision log. |

## Verification

- [ ] Nothing was created before the intake completed (or an explicit `--no-grill`/`--dry-run` was stated in the report)
- [ ] Every applicable intake question was actually put to the user, one at a time
- [ ] Every recorded answer is the user's verbatim reply — nothing invented, unasked questions marked `(not asked)`
- [ ] All intake answers recorded, stamped, in the `docs/DECISIONS.md` init entry (appended, if the file pre-existed)
- [ ] Unfilled placeholders and tracked-but-newly-ignored files flagged

## Does not

- Overwrite or restructure existing content — retrofit means *adding what's missing*, only.
- Set up environments or lockfiles (suggests it as a next step when Q5 warrants), install anything, or make commits.
- Scaffold helper modules like `utilities.py` — if the user maintains a shared helper library (their global CLAUDE.md will say so), point the scaffolded AGENTS.md at it; otherwise leave the placeholder comment.
- Carry any project-specific or person-specific references — templates stay neutral and fully usable on a clean machine.
