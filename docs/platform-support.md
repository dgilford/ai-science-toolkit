# Platform support

The toolkit is developed on macOS and Linux. This page records **what currently
works on Windows without modification**, what breaks, and why — so Windows users
know which pieces they can adopt today, and so the porting work has a baseline.

Nothing here is aspirational. Claims are marked **verified** (executed on the test
machine), **inferred** (read from source, not executed), or **untested**.

## Test environment

| | |
|---|---|
| OS | Windows 11 Education 26200 |
| Shell | PowerShell 7 (Claude Code default on Windows) |
| Claude Code | 2.1.220, Node v26.3.0, platform `win32` |
| Git | Git for Windows 2.55.0.3, `core.autocrlf=true` (installer default) |
| Python | 3.13.14 |

Audited 2026-07-30 by executing every shell preamble in the repo and measuring
the result. Harnesses are described inline below so the numbers can be reproduced.

## Summary

| Tier | What | Windows status |
|---|---|---|
| Reviewer agents (all 4) | pure Markdown, zero shell | ✅ **fully portable** |
| Prose-only skills (8) | instructions to the model, zero shell | ✅ **fully portable** |
| Plugin install path | `/plugin marketplace add` | ✅ **portable** (inferred) |
| Status line | works once `jq` is installed | ⚠️ **works, but costly** |
| Skills whose shell the *model* runs (3) | model can translate to PowerShell | ⚠️ **degraded** |
| Repo scripts (`sync.sh` et al.) | need Git Bash + setup | ⚠️ **works with setup** |
| Line endings | every `.sh` checks out CRLF | ❌ **breaks the lint gate** |
| Skills with a `` ```! `` preamble (10) | **0 of 16 blocks execute** | ❌ **broken** |
| Session auto-naming hook | terminal integration is iTerm2/VS Code only | ❌ **feature absent** |

**Roughly half the toolkit — everything whose value is the prompt rather than the
plumbing — works on Windows untouched.** The breakage is concentrated in the
shell layer, and is dominated by two causes: PowerShell-incompatible preambles,
and CRLF line endings.

## ✅ Works unmodified

### Reviewer agents — all four

`attribution-reviewer`, `stats-reviewer`, `meteo-reviewer`, `scicomm-reviewer`.
**Verified:** zero shell blocks across all four files. They are Markdown personas;
nothing platform-specific can occur.

### Prose-only skills

**Verified** (no `` ```! `` preamble, no shell block of any kind):

`commit-batch` · `evolve-claude-md` · `grill-me` · `grilling` · `overbaked` ·
`pathfinder` · `reviewer-2` · `write-new-skill`

`commit-batch` is portable only because it is a thin launcher — the
`commit-batching` core it delegates to has a broken preamble.

### Plugin installation

```
/plugin marketplace add dgilford/ai-science-toolkit
/plugin install ai-science-toolkit@ai-science-toolkit
```

**Inferred, untested on Windows.** No shell is involved — Claude Code fetches and
registers the bundle itself. It is the recommended Windows install route because
it avoids `sync.sh`, Git Bash, and the CRLF problem entirely. It does not register
the boot hook, which does not work on Windows anyway.

## ❌ Preambles: 0 of 16 blocks execute

Preamble blocks run **in PowerShell**, not bash. **Verified** by executing all 15
blocks from the 9 skills the harness covered, verbatim, exactly as Claude Code
would:

```
TOTAL: 15 blocks | OK=0  FAIL=15
```

Every one fails. Because a preamble runs *before* Claude sees the skill, the
skill body loads with an error where its repo context should be.

A 16th block was missed by that harness run: `worklog` was filed under [skills
whose shell the model runs](#skills-whose-shell-the-model-runs), but its
week's-Monday computation is a genuine `` ```! `` preamble carrying `2>/dev/null`
— and it was independently **verified failing** live (it "could not compute the
week's Monday"). Counting it, the preamble surface is **16 blocks across 10
skills**.

| Skill | Blocks | Failing constructs |
|---|---|---|
| `ai-review` | 1 | `2>/dev/null`, `head -N` |
| `commit-batching` | 1 | `2>/dev/null` |
| `create-alert` | 2 | `VAR=`, `${x:+y}`, `if/then/fi`, `2>/dev/null` |
| `figure-review` | 2 | `VAR=`, `${x:+y}` |
| `handoff` | 3 | `2>/dev/null`, `head -N` |
| `repo-init` | 2 | `VAR=`, `${x:+y}`, `2>/dev/null` |
| `resume` | 2 | `2>/dev/null` |
| `slack-message` | 1 | `2>/dev/null`, `head -N`, `basename` |
| `unstale` | 1 | `2>/dev/null` |
| `worklog` | 1 | `2>/dev/null` (verified separately, not in the harness total above) |

### How much does each fix buy?

Measured by rewriting every block and re-executing:

| Repair | Blocks passing |
|---|---|
| none (as shipped) | **0 / 15** |
| strip `2>/dev/null` only | **7 / 15** |
| + swap `head`/`basename` for PowerShell equivalents | **10 / 15** |

The `/15` denominators are the harness run; `worklog`'s 16th block fails only on
`2>/dev/null`, so it joins the strip-`2>/dev/null` cohort (its `python3` computation
runs once Python is shimmed).

> **Correction:** an earlier draft of this page claimed that fixing `2>/dev/null`
> alone "unblocks most of the broken surface." Measurement shows it fixes **47%**,
> not most. It is still the single highest-leverage change — it is the only one
> that moves the number off zero — but it is not sufficient.

The **5 residual failures** are all the same pattern: the companion-file loaders in
`figure-review` (×2), `create-alert` (×1 of 2), and `repo-init` (×1 of 2). They use
a bash variable assignment plus `${CLAUDE_PLUGIN_ROOT:+…}` to locate `COLORBLIND.md`,
`CC-STYLE.md`, `HARDENING.md`, and `TEMPLATES.md`. These need a genuine rewrite, not
a substitution — and they fail hardest, because `create-alert` and `repo-init` are
specified to **abort** when their companion is missing. They do not degrade; they
refuse to run.

### What already works in a PowerShell preamble

**Verified:** bare `git …` invocations, `&&` and `||` chaining (PowerShell 7),
`echo`, `cat`, and `git check-ignore -q X && echo yes || echo no`.

Note that `2>/dev/null` is not merely unnecessary in PowerShell — `||` still
catches a failing command without it — it is actively fatal.

## ❌ Line endings: CRLF breaks the lint gate

**Verified, and the most easily fixed problem here.** The repo has **no
`.gitattributes`**, and Git for Windows defaults to `core.autocrlf=true`. Every
tracked shell script therefore checks out with CRLF:

| File | CRLF lines |
|---|---|
| `scripts/sync.sh` | 507 |
| `scripts/gen-docs.sh` | 169 |
| `vscode-extension/install.sh` | 91 |
| `scripts/ai-sessions.sh` | 85 |
| `tests/smoke_test_parsers.sh` | 69 |
| `settings/statusline-command.sh` | 61 |
| `scripts/lint-shell.sh` | 57 |

That is 100% of tracked `.sh` files.

**What it does *not* break:** execution. Git Bash runs these scripts fine —
`sync.sh push` completes, and the CRLF status line renders correctly.

**What it does break:** the repo's own shell lint. On a Windows clone,
`scripts/lint-shell.sh` reports **471 × SC1017 (literal carriage return)** and
exits 1, plus cascading parse errors (SC1041–SC1047, SC1072, SC1073, SC1140) that
are artefacts of the CR rather than real defects. A Windows contributor cannot
pass the project's own gate, and the genuine findings are buried.

**Verified fix:** stripping CR from a scratch copy makes shellcheck exit 0 with the
same ruleset. A `.gitattributes` containing `*.sh text eol=lf` would prevent the
whole class.

Note the deployed copies inherit this too — `~/.claude/skills/tab-setup/scripts/hook-startup.sh`
carries 457 CRLF lines after a `sync.sh push`.

## ⚠️ Works, with caveats

### Status line

**Verified working** against a real captured payload:

```
🪟 Context: 24% used (76% remaining) | 🤖 Opus 5 | 🪨 effort: high | ⏰ 5h: 74%
```

Both Windows problems it had are now fixed on the `pc-compatibility` branch; the
notes below are what a Windows user hits on the released version.

- **`jq` is a hard dependency**, is not a Windows default, and — the part that
  actually bites — **installing it is not enough**. `winget install jqlang.jq`
  writes the new directory to the *registry* PATH, but an already-running Claude
  Code keeps the environment it launched with, so the status line's bash inherits
  a PATH without `jq`. winget also creates no `WinGet\Links` shim for this
  package, so the binary exists only under a hashed `Packages\jqlang.jq_*\`
  directory and PATH is the only route to it. The symptom is a blank
  `🪟 Context: -- | 🤖` that looks like "no data" rather than a missing
  dependency. *Fixed:* the script now searches known install locations and says
  what is wrong when it still cannot find `jq`.
- **Cost.** Four separate `jq` calls put the render at **~316 ms** against a
  ~300 ms refresh cadence, so it never settled. Decomposed: bash spawn is only
  36 ms; each `jq` inside Git Bash costs ~70 ms. *Fixed:* one `jq` pass, **141 ms**.
  Note a native PowerShell rewrite was measured and is **worse** (342 ms) — `pwsh`
  startup alone is 256 ms. Any per-render subprocess is expensive on Windows.

### Skills whose shell the model runs

Portable *as prose*; only their worked examples are Unix-shaped. Claude can
translate on the fly, but the skill text will not match what runs.

| Skill | Unix-only content |
|---|---|
| `worklog` | `date +%F`, `basename`, `printf`, `mkdir -p`, `ssh`. **Verified failing** live: produced `Out-File: Could not find a part of the path 'C:\dev\null'` and could not compute the week's Monday. |
| `lit-review` | two Zotero examples using `curl` + `python3`. `curl.exe` ships with Windows and `python3` works once shimmed, but `$ZOTERO_USER_ID` does not expand in PowerShell. |
| `unstale` | the `ruff`/`vulture` core is Python and portable; only its preamble breaks. |

### Repo scripts

`sync.sh`, `gen-docs.sh`, `lint-shell.sh`, `ai-sessions.sh` are bash and require
Git Bash. **Verified:** `sync.sh push` completes on Windows after the setup below.
`gen-docs.sh check` passes.

`ai-sessions.sh` is designed to be sourced from `~/.bashrc`/`~/.zshrc`, which has
no PowerShell equivalent; it is usable only inside a Git Bash session.

## ❌ Session auto-naming hook

**Inferred from source.** `hook-startup.sh` targets iTerm2 (via `osascript`) or
VS Code (via a `.pending-color` file). Windows terminals match neither, so it falls
through to a stderr message telling you to run `/color` and `/rename` yourself.
The auto-naming feature simply does not work.

> **Caution:** on the audit machine, enabling the hook and status line — by putting
> `bash` on PATH, which is what lets them run at all — coincided with repeated hard
> exits of Claude Code. Root cause was never confirmed (no OOM, no OS fault events,
> pagefile peak 65 MB). Treat both as suspect on Windows until someone reproduces
> cleanly.

## Dependencies

| Dependency | Needed by | Windows default |
|---|---|---|
| `bash` | all repo scripts, both boot integrations | ⚠️ ships with Git for Windows in `Git\bin`, which the installer does **not** add to PATH |
| `jq` | status line (×4), the documented model/effort pin hook | ❌ absent |
| `PyYAML` | `sync.sh` frontmatter lint, `smoke_repo_init.py` | ❌ absent |
| `python3` | `sync.sh` (×6), `hook-startup.sh` | ⚠️ resolves to the Windows Store stub, which prints an install prompt and exits nonzero |
| `shellcheck` | `lint-shell.sh` | ⚠️ **verified**: `pip install shellcheck-py` puts it in `Python313\Scripts`, not the `~/.local/bin` the script special-cases. It is found anyway, via `command -v` — the `~/.local/bin` fallback is Linux-specific and inert here. |

Missing `PyYAML` degrades **inconsistently**: `lint_frontmatter()` skips with a
warning, but `smoke_repo_init.py` hard-fails, so the push dies with a confusing
template error instead of one clear "install PyYAML".

### Encoding

`sync.sh`'s Python heredocs call `open()` with no `encoding=`. Windows defaults to
cp1252, which raises `UnicodeDecodeError` on non-ASCII already present in the skill
files. **Verified:** byte `0x8f` at position 5017 aborts the skill-reference lint.
Workaround `PYTHONUTF8=1`; fix is `encoding="utf-8"` at each call site.

## Windows setup today

Until the porting work lands, this is the verified working configuration.

```powershell
winget install Git.Git GitHub.cli jqlang.jq
python -m pip install pyyaml shellcheck-py
```

Then, once:

- Add `C:\Program Files\Git\bin` to your user PATH so `bash` resolves.
- Create a `python3.exe` copy of `python.exe` in your Python install directory —
  Windows' `python3` is an App Execution Alias stub. Works only if that directory
  precedes `WindowsApps` on PATH.
- Set `PYTHONUTF8=1` before running the sync. In PowerShell that is
  `$env:PYTHONUTF8 = "1"` on its own line — the bash-style `PYTHONUTF8=1 bash …`
  prefix is a syntax error in PowerShell.
- For a non-interactive push add `SYNC_EXTERNAL_ACCEPT=1`. The `tab-setup` review
  gate reads stdin, and under `set -euo pipefail` an EOF there aborts the script
  silently rather than declining.

Prefer the **plugin install** if you only want skills and agents — it needs none of
the above.

## Not yet verified

- Whether preambles run under PowerShell in *every* Windows configuration, or only
  when PowerShell is the selected shell. Fifteen verbatim failures are consistent
  with the former but do not prove it.
- The plugin install path end-to-end on Windows.
- Whether the boot hook or status line caused the hard exits observed here.
- WSL, which likely behaves as Linux throughout and would sidestep all of this.
