# PC compatibility — approach

Working document for the `pc-compatibility` branch. Goal: make the toolkit a
first-class Windows citizen without forking it into two codebases.

Baseline measurements live in [platform-support.md](platform-support.md); this page
is the plan, not the audit. Every sequencing decision below is justified by a
number from that audit.

## Principles

1. **One implementation, not two.** This repo has already been burned by
   deliberate duplication — the `vscode-extension/` fork-vs-tracked split drifted
   undetected for weeks in both directions and cost the whole `/color` injection
   path. A parallel PowerShell port of `sync.sh` would recreate that failure mode
   with far more surface. Prefer *portable* over *ported*.
2. **Fix causes, not symptoms.** `2>/dev/null` appears in nine skills. Fix the
   construct everywhere rather than special-casing Windows at each call site.
3. **No platform branching inside preambles.** A `!` preamble is a one-liner with
   no reliable way to detect the shell. If a preamble cannot be written in the
   bash∩PowerShell subset, it should not be a preamble.
4. **Degrade loudly, never silently.** The current Windows experience is mostly
   silent: blank status line, missing companion files, phantom lint errors. A
   missing dependency should say so.
5. **Windows users who only want skills should not need a shell at all.** The
   plugin path already achieves this; keep it that way.

## Sequence

Ordered by measured leverage per unit of effort.

### 1. `.gitattributes` — unblocks the contributor gate

**One file. Highest leverage in the whole plan.**

No `.gitattributes` exists, so Git for Windows (`core.autocrlf=true` by default)
checks out 100% of tracked `.sh` files as CRLF. Execution survives it, but
`scripts/lint-shell.sh` emits **471 × SC1017** and exits 1 — a Windows contributor
cannot pass the project's own gate, and real findings are buried under phantom
parse errors. Verified: stripping CR makes shellcheck exit 0 on the same ruleset.

```gitattributes
* text=auto eol=lf
*.sh   text eol=lf
*.ps1  text eol=crlf
*.png  binary
```

Renormalise once with `git add --renormalize .` after adding it.

Open question: whether `*.ps1` should be CRLF. PowerShell 7 reads LF fine; CRLF is
the Windows convention. Low stakes — pick one and state it.

### 2. Preambles into the portable subset — 0/15 → 10/15

**Verified safe in both shells:** bare `git …`, `&&`, `||`, `echo`, `cat`.
**Verified fatal in PowerShell:** `2>/dev/null`, `head -N`, `basename`, `VAR=x`,
`${x:-y}`, `[ -n … ]`, `if/then/fi`, `date +%F`.

Two mechanical substitutions, applied across all nine skills:

- **Drop `2>/dev/null` entirely.** It is not merely unportable, it is unnecessary —
  `||` still catches a failing command in both shells. Takes preambles 0/15 → 7/15.
- **Drop `| head -N` and `basename`.** `git log -N` already limits output; `git
  status --short` is short by construction. Reaches 10/15.

This is a pure deletion pass. No new abstraction, no platform detection.

### 3. Companion-file loaders — the residual 5

The 5 blocks that survive step 2 are all one pattern, in `figure-review` (×2),
`create-alert`, and `repo-init`:

```bash
D="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/figure-review}"; D="${D:-$HOME/.claude/skills/figure-review}"; cat "$D/COLORBLIND.md"
```

This is bash parameter expansion with no PowerShell equivalent, so it cannot be
substituted — it needs replacing. These fail hardest: `create-alert` and
`repo-init` are specified to **abort** when their companion is missing, so on
Windows they refuse to run rather than degrading.

✅ **Done.** Preambles now execute **11/11 under PowerShell and 11/11 under bash**
(the block count fell from 15 because four preambles were deleted outright). The
resolution split by whether the content is conditional and how large it is:

| Companion | Size | Needed | Resolution |
|---|---|---|---|
| `create-alert` hardening | 12 lines | every invocation, verbatim | **inlined into SKILL.md**; file deleted |
| `figure-review` `COLORBLIND.md` | 60 lines | every invocation | relative link + "read this first" |
| `figure-review` `CC-STYLE.md` | 36 lines | only under `--style` | relative link, conditional |
| `repo-init` `TEMPLATES.md` | 354 lines | before scaffolding | relative link + abort-if-missing |

Inlining won for the hardening block because it is short, unconditional, and must
be reproduced *verbatim* — indirection bought nothing and its failure mode was a
routine that looks complete but has no injection defenses. The others are too
large to inline, so they take the link, always paired with an explicit instruction
about when to read it and what to do if it is missing, since **a link is lazy
where a preamble was eager**.

Two things fixed in passing: `create-alert`'s `ALERT_SLACK_DEFAULT_LOCATION` probe
moved from shell into prose (no env-var test behaves the same in both shells, and
one that silently reports "unset" on Windows would quietly drop the default), and
its gitignore probe now anchors with `git -C "$(git rev-parse --show-toplevel)"`,
which preserves the documented repo-root-anchoring gotcha *and* behaves
identically in both shells.

**Original reasoning, retained:**

**Proposed fix: delete the preamble and use a relative Markdown link.**
`lit-review` already does exactly this with `REFERENCE.md` — the link resolves from
the SKILL.md's own directory, so it works identically under a `sync.sh` deploy and
a plugin install, with no `CLAUDE_PLUGIN_ROOT` branch and no shell at all. That
retires the `${CLAUDE_PLUGIN_ROOT:+…}` idiom the repo currently documents as the
required pattern.

**Trade-off to settle before implementing:** the `!` preamble *guarantees* the
companion is in context before Claude reads the skill body. A Markdown link relies
on Claude choosing to follow it. For `figure-review`'s style guides that is
probably fine; for `create-alert`'s `HARDENING.md` — which is baked verbatim into
every generated cloud-routine prompt — a silent skip would be a security
regression, not a cosmetic one. That case may need to stay eager, in which case
the fix is a PowerShell-safe rewrite rather than a link.

### 4. `sync.sh` portability — two unfixed bugs ✅ done

`bash scripts/sync.sh lint` now passes on Windows with **no workarounds** — no
`PYTHONUTF8=1`, no `SYNC_EXTERNAL_ACCEPT=1`. Four changes:

- **`encoding="utf-8"` on all 7 `open()` calls.** Retires the `PYTHONUTF8=1`
  prefix, which was itself a Windows trap: the bash-style `PYTHONUTF8=1 cmd`
  form is a syntax error in PowerShell.
- **`read -r reply || reply=n`.** Verified: the gate now reaches its
  decline-and-roll-back path on non-TTY stdin instead of aborting silently.
- **PyYAML degrades consistently.** The real defect was narrower than "hard-fails
  vs skips": `smoke_repo_init.py` imported yaml *inside* the per-block
  `try/except Exception`, so a missing module was reported as `yaml block does
  not parse: No module named 'yaml'` — a fake parse failure naming the wrong
  cause, once per block, while every other consumer skipped with a warning.
  Import is hoisted; all three sites now skip identically. `REQUIRE_PYYAML=1`
  (set in CI) turns the skip into a hard failure, mirroring `REQUIRE_SHELLCHECK`.
- **`diff --strip-trailing-cr` in `lint_vscode_extension()`.** A regression from
  step 1: the tracked copy obeys the new `.gitattributes` (LF) while `tab-setup/`
  is an independent clone that lands CRLF on Windows, so every file read as
  drifted. The lint is for content drift; on Linux/macOS both are LF and this is
  a no-op.

**Original reasoning, retained:**

Both already documented in CLAUDE.md; neither is Windows-specific in nature, only
in symptom.

- **`open()` without `encoding=`** in six Python heredocs. Windows' cp1252 default
  raises `UnicodeDecodeError` on non-ASCII already present in the skill files
  (verified: byte `0x8f`). Fix at each call site; retire the `PYTHONUTF8=1`
  workaround.
- **`read -r reply` under `set -euo pipefail`.** On non-TTY stdin the EOF return
  aborts the script silently instead of taking the intended decline-and-rollback
  path. `read -r reply || reply=n` restores the designed behaviour.

Also worth fixing: **PyYAML degrades inconsistently** — `lint_frontmatter()` skips
with a warning while `smoke_repo_init.py` hard-fails, so the push dies with a
confusing template error instead of one clear "install PyYAML". Make both behave
the same way.

### 5. The Windows pathway — `install.ps1`

A bootstrapper, **not** a port of `sync.sh`. Per principle 1, it should install
prerequisites and then delegate:

- install `git`, `jq`, `python`, `gh` via winget (idempotent, skip when present)
- `pip install pyyaml shellcheck-py`
- resolve the `python3` problem — Windows' `python3` is an App Execution Alias
  stub that prints an install prompt and exits nonzero
- put `C:\Program Files\Git\bin` on PATH so `bash` resolves (Git's installer adds
  only `Git\cmd`, which has `git.exe` alone)
- set `PYTHONUTF8=1`, then invoke `bash scripts/sync.sh push`

Every one of these steps was performed by hand during the audit and is known to
work; this script is the automation of a verified manual sequence, not a design.

Open question: should `install.ps1` exist at all, or should Windows users be
pointed at the plugin install plus a short prerequisites list? The plugin path
needs none of this. `install.ps1` is only worth building for people who want the
repo scripts and the boot integrations.

### 6. Status line — collapse the jq calls ✅ done

**Currently works** on Windows once `jq` is installed. The objection was cost, not
correctness. Decomposing where the time went:

| | ms/render |
|---|---|
| bash spawn alone | 36 |
| bash + 1 `jq` | 112 |
| **bash + 4 `jq` (as shipped)** | **316** |
| `pwsh` startup alone | 256 |

Claude Code refreshes roughly every 300 ms, so at 316 ms the render never finished
before the next was due — a saturated duty cycle continuously churning five
processes. That is Windows-specific: the same four forks are nearly free on Linux.

> **A rejected approach, recorded so it is not retried.** The original plan here
> was a native `statusline-command.ps1`. It was written and measured: **342 ms,
> *slower* than the bash version.** `pwsh` startup alone is 256 ms. The bottleneck
> was never bash — bash spawn is only 36 ms — it was the four `jq` calls at ~70 ms
> each. Any per-render subprocess is expensive on Windows; the language does not
> matter. The port was deleted.

**Shipped fix:** one `jq` pass instead of four. **278 → 141 ms, 2.0×**, verified
byte-identical against the previous implementation across 8 input cases
(missing effort, missing 5h, empty object, fractional percentages, every colour
threshold). Keeps a single implementation, so principle 1 holds, and it helps
Linux and macOS too — just less dramatically.

Two traps found while doing it, both now commented in the script:

- **The separator must not be tab.** Tab is an IFS *whitespace* character, so bash
  collapses runs of it and an absent middle field shifts every later value left —
  an absent `effort` rendered the 5h percentage as the effort level. Uses US
  (``) instead, written as a jq escape rather than a literal control byte.
- **The jq program must stay on one line.** The file is checked out CRLF on
  Windows, and a multi-line jq program carries those CRs into the extracted
  values, corrupting every field.

Both bugs were caught only by byte-comparing output against the old script. Any
further change here needs the same parity check.

**Still unresolved:** whether this was ever the cause of the hard exits. The
crashes stopped when the status line was disabled, and it is now 2× cheaper and
under the refresh cadence — but that is correlation plus a plausible mechanism,
not a proven diagnosis.

### 7. `tab-setup` — deliberately last

Auto-naming targets iTerm2 (`osascript`) or VS Code (`.pending-color`). Windows
terminals match neither, so the feature is simply absent — it does not
misbehave, it no-ops with a stderr hint.

This is the largest piece and the least certain payoff, and it lives in a separate
fork (`dgilford/tab-setup`) with its own maintenance path. Windows Terminal
supports tab colour/title via OSC escape sequences, so a third backend is
feasible — but it should not block anything above it.

**Blocker:** during the audit, enabling the boot hook and status line coincided
with repeated hard exits of Claude Code. Root cause was never established (no OOM,
no OS fault events, pagefile peak 65 MB). **Reproduce and explain that before
investing here** — building a Windows backend for a hook that may be destabilising
the client would be premature.

## Explicitly out of scope

- **WSL.** Almost certainly works as Linux today. If so, documenting it is the
  entire deliverable.
- **cmd.exe.** PowerShell 7 is Claude Code's Windows default; supporting a third
  shell multiplies the matrix for no known user.
- **Rewriting skill prose.** The prompt layer is already portable — 8 skills and
  all 4 agents work untouched. Do not touch what works.

## Verification

Anything landed on this branch should be checked against the harnesses used for
the audit, which live in the session scratchpad and should be promoted into
`tests/` if this work continues:

- execute all `!` preamble blocks under PowerShell; assert 15/15 pass
- assert no tracked `.sh` contains CRLF
- `bash scripts/lint-shell.sh` exits 0 on a fresh Windows clone
- `bash scripts/gen-docs.sh check` exits 0
- `sync.sh push` completes without `PYTHONUTF8=1`

A CI job on `windows-latest` would make the first three permanent. Currently every
workflow runs on Linux only, which is why none of this was caught.
