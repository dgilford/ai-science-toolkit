# tab-setup maintenance runbook

Occasional-use procedures for the external `tab-setup` skill. The two rules that matter
mid-session live in `CLAUDE.md` (edit `tab-setup/scripts/`, never `skills/tab-setup/`;
`sync.sh push` overwrites the deployed copy).

## Fork relationship

`dgilford/tab-setup` is a **fork of `JeraldHuff/tab-setup`** (the upstream). `sync.sh push`
pulls the fork into `tab-setup/` (a nested git repo at the repo root) *before* copying its
`scripts/` and `vscode-extension/` into `skills/tab-setup/`.

To change tab-setup scripts: edit `tab-setup/scripts/`, commit and push to
`dgilford/tab-setup`, then run `sync.sh push`. Contribute changes back to Jerald with
`gh pr create --repo JeraldHuff/tab-setup --base main --head dgilford:<branch>`.

## Pulling new upstream (Jerald) work into the fork

```sh
git -C tab-setup remote add upstream https://github.com/JeraldHuff/tab-setup.git  # once
git -C tab-setup fetch upstream
# fast-forward main to upstream/main, then:
git -C tab-setup push origin main
bash scripts/sync.sh push
```

**Caveats:** `sync_external_skills()` copies only `scripts/` and `vscode-extension/` into
`skills/tab-setup/` — **not** `SKILL.md` or `README.md` — and `cp -r` never prunes files
deleted upstream (stale scripts can linger in the deployed dir; remove them by hand). If
Jerald updates `SKILL.md`, copy it over `skills/tab-setup/SKILL.md` manually.

## `/tab-setup update` (alternate refresh path)

tab-setup ships its own self-update command: `/tab-setup update` → `scripts/update.sh`, which
`git pull --ff-only`s the fork at the path recorded in `~/.claude/skills/tab-setup/.repo-path`
and re-runs `install.sh` (re-copies skill files + rebuilds the VS Code/code-server extension).
It's a quick, **tab-setup-only** refresh — it does **not** deploy other skills/agents, lint,
or register the hook (that's `sync.sh push`'s job).

- `.repo-path` is written by `install.sh`, **not** `sync.sh`. It was bootstrapped once
  (`bash tab-setup/scripts/install.sh`) to point at `tab-setup/`; `sync.sh push` never
  overwrites or deletes it, so `/tab-setup update` keeps working.
- It pulls from `origin` (your fork), not Jerald's `upstream` — so it only sees new Jerald
  work *after* the fork's `main` has been synced to upstream (see above).
- `update.sh` refuses to run if `tab-setup/` has uncommitted changes, and only
  fast-forwards — safe, won't clobber.
