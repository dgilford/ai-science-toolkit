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

## The claude-tab extension lives in two places

`/tab-setup/` is gitignored here, so the fork's copy of the extension isn't in this repo's
tracked tree — which means **the tracked `vscode-extension/` is the only copy CI can review
and unit test** (`tests/smoke_test_session_status.js`, run by `smoke_test_parsers.sh`). Both
copies are load-bearing:

| Copy | Role |
|---|---|
| `tab-setup/vscode-extension/` | fork checkout — **what actually deploys** |
| `vscode-extension/` | tracked mirror — what CI lints and unit tests |

**Authoring order: fork first, then mirror into `vscode-extension/`.** `lint_vscode_extension()`
in `scripts/sync.sh` fails the push when the two trees differ, and is skipped when `tab-setup/`
is absent (fresh clone, CI). They silently drifted for weeks in both directions before that
tripwire existed — see below.

### Failure mode this class of bug takes

The extension is installed by copying files into the server's extension dir. A missing file
does **not** produce a visible error: the extension still registers in `extensions.json`, so
`/tab-setup` reports success and `setup.sh` keeps writing `~/.claude/.pending-color` normally
— but `activate()` throws, the poller never starts, `.pending-color` is never consumed, and
`/color` is simply never injected. The only evidence is one line in the extension host log:

```sh
# newest exthost log dir; grep for the extension
L=~/.local/share/code-server/logs/*/; grep -i claude-tab $(ls -dt $L/exthost*/ | head -1)/remoteexthost.log
```

Two separate installers had enumerated-copy bugs of exactly this shape (`vscode-extension/install.sh`
omitting `lib/`; `scripts/install.sh` omitting it again for the deployed skill dir). Both now copy
the tree wholesale and verify it post-copy. **When adding a file to the extension, prefer directory
copies over naming files.**

A stale `.pending-color` sitting in `~/.claude/` is the quickest smell that the extension is dead —
a healthy one is consumed within ~500ms.

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

`install.sh`'s post-copy verify diff is what surfaces those orphans — it exits non-zero on
`Only in <dest>` — but it only runs on the `/tab-setup update` path, so a broken `.repo-path`
hides them. `scripts/watcher.sh` (deleted upstream in c1b3e62) lingered this way and had to be
removed by hand from both `skills/tab-setup/scripts/` and `~/.claude/skills/tab-setup/scripts/`.

## `/tab-setup update` (alternate refresh path)

tab-setup ships its own self-update command: `/tab-setup update` → `scripts/update.sh`, which
`git pull --ff-only`s the fork at the path recorded in `~/.claude/skills/tab-setup/.repo-path`
and re-runs `install.sh` (re-copies skill files + rebuilds the VS Code/code-server extension).
It's a quick, **tab-setup-only** refresh — it does **not** deploy other skills/agents, lint,
or register the hook (that's `sync.sh push`'s job).

- `.repo-path` is written by `install.sh`, **not** `sync.sh`. It was bootstrapped once
  (`bash tab-setup/scripts/install.sh`) to point at `tab-setup/`; `sync.sh push` never
  overwrites or deletes it, so `/tab-setup update` keeps working.
- **That cuts both ways: because `sync.sh` never rewrites `.repo-path`, moving the checkout
  breaks `/tab-setup update` silently and indefinitely.** It was found pointing at a long-gone
  `~/ai-tools/tab-setup`, so `update.sh` had been dying on *"recorded repo path is not a git
  checkout"* while `sync.sh push` kept working — which also masked the stale-file check below.
  After relocating the checkout, re-point it: `printf '%s\n' "$PWD/tab-setup" > ~/.claude/skills/tab-setup/.repo-path`.
- It pulls from `origin` (your fork), not Jerald's `upstream` — so it only sees new Jerald
  work *after* the fork's `main` has been synced to upstream (see above).
- `update.sh` refuses to run if `tab-setup/` has uncommitted changes, and only
  fast-forwards — safe, won't clobber.
