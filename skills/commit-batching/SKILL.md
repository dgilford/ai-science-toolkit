---
name: commit-batching
description: Batch a dirty working tree into logical, single-concern commits instead of one monolithic `git add -A`. Use whenever you are about to commit and more than one file or concern has changed — survey every change, group by concern, stage each group by explicit path, write a focused message per commit, then push only if authorized.
allowed-tools: Bash Read
catalog:
  order: 160
  summary: 'Batch a dirty working tree into logical, single-concern commits (survey → group → stage by path → commit → push if asked) — the model-invokable core behind `/commit-batch`.'
---

You are about to commit. Do **not** `git add -A && git commit` the whole tree at once. Group the pending changes into logical, single-concern commits first.

## Current working tree

```!
git status --short 2>/dev/null || echo "(not a git repo)"
echo "--- branch ---"; git rev-parse --abbrev-ref HEAD 2>/dev/null || true
echo "--- staged/unstaged stat ---"; git diff --stat HEAD 2>/dev/null || true
echo "--- untracked ---"; git ls-files --others --exclude-standard 2>/dev/null || true
```

## Method

1. **Survey** — run `git status` (staged, unstaged, *and* untracked) and read enough of `git diff` to understand each change's intent. Never stage what you haven't looked at.
2. **Plan** — group changed paths into single-concern batches and draft a one-line message for each. Present the plan as a compact list *before* executing.
3. **Execute per group** — `git add <explicit paths>` → confirm `git diff --cached --stat` matches the intended group → commit with a focused message. Repeat for the next group.
4. **Verify tree** — after the loop, `git status` should be clean (or leave only paths you deliberately chose not to commit).
5. **Push** — only if the original request asked you to push. Respect the repo's branching convention (branch first unless the project says commit straight to main).

## Grouping principles

- **One concern per commit.** A feature, a bugfix, a refactor, and a config/dependency bump are separate commits even when touched in the same working session.
- **Documentation folds in.** A README or doc update that documents a specific batch belongs *inside that batch's commit*, not a standalone "update docs" commit. If one doc file's edits span several batches and can't be cleanly split, fold the whole doc change into the **last** batch you commit.
- **Generated/mechanical changes** (lockfiles, formatting sweeps, generated tables) go either with the change that caused them or in their own clearly-labeled commit — never silently folded into a feature commit.
- **Order for coherence.** Put prerequisites (a helper, a rename, a refactor) before the change that consumes them, so each commit stands on its own.
- **Don't over-split.** One logical change spread across N files is one commit, not N.

## Staging safety

- Stage by **explicit path** for every group — never `git add -A` / `git add .`; they sweep in scratch files, secrets, and unrelated edits.
- Account for *every* path in `git status`; include untracked files only when they belong to the group.
- Before staging, scan for things that must not be committed — secrets, `.env`/credentials, large artifacts, scratch/temp output, editor cruft. Stop and flag rather than commit them.
- When one file mixes two concerns, commit it with the group it most belongs to and note the rider in the message. Interactive `git add -p` is unavailable in this environment; for a true hunk split, construct a patch and `git apply --cached`, or state the limitation.
- Use a plain quoted `-m` string (heredoc commit messages fail here); include any trailer the repo/harness requires (e.g. `Co-Authored-By`).

## Anti-Rationalization

| Excuse | Reality |
|---|---|
| "It's all one change — one commit is fine." | If the diff spans more than one concern (code + docs + config + refactor), it isn't one change. Split by concern. |
| "`git add -A` is faster." | It also stages secrets, scratch files, and unrelated edits into one blob. Stage explicit paths. |
| "I'll squash/fixup it later." | Squash *merges* commits; it cannot split a monolithic one without manual surgery. Get the boundaries right up front. |
| "Only one file changed — skip the survey." | Batching is then trivially one commit, but still survey for untracked files and secrets before staging. |
| "The user is in a hurry — skip the plan." | The plan is a 3-line list; an entangled commit costs far more to untangle in review or revert. |

## Verification

- [ ] Surveyed **all** changes (staged, unstaged, untracked) with `git status` + `git diff` before staging.
- [ ] Every commit staged explicit paths — no `git add -A` / `git add .`.
- [ ] No secrets, env files, credentials, or scratch artifacts staged (checked each group).
- [ ] Each commit message names one concern; `git diff --cached --stat` matched the group before committing.
- [ ] `git status` clean, or only intentionally-unstaged paths remain, after the loop.
- [ ] Pushed only if the request authorized it; branching convention respected.
