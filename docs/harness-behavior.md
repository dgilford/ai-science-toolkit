# Harness behavior — observed, not documented

Claude Code's own behavior, as *observed from inside sessions*. Everything here
is undocumented internals of a proprietary CLI that ships new versions weekly.
None of it is contract.

This file exists because these facts are volatile and `CLAUDE.md` is loaded into
context on every single run. Volatile observations belong here; only the stable
consequence belongs in `CLAUDE.md`.

## How to read the evidence tier

| Tier | Means |
|---|---|
| **observed** | Seen directly in session context, at the stated CLI version. Usually n=1 — read the confounds column before generalizing. |
| **inferred** | Follows from something observed, but the step itself was never watched. Treat as a hypothesis. |
| **reported** | A human reported it; the session could not verify it independently. Weakest tier. |

Record the **CLI version**, not just the date — these are parser and loader
properties, and a version bump can invalidate any row silently. Nothing in CI
tests these claims; a stale row will not announce itself.

## Slash-command expansion

Rows 2, 3, 4, 4b and 6 come from interactive sessions on **CLI 2.1.220**, macOS
(darwin 25.5.0), 2026-08-03/04. Rows 1, 5 and 7 have their own provenance in the
confounds column — the version stamp is per row, not per table.

**One rule generates rows 1–4b.** Tokens expand while everything before them in
the submission is command material; the first non-command token begins the
argument text, and everything after it — including a later `/<name>` — is inert.
The rows are kept separate because each was observed independently and the rule
is the inference from them, not a documented contract.

| # | Claim | Tier | Confounds / limits |
|---|---|---|---|
| 1 | A command at the start of a submission expands: the session receives a `<command-name>` block plus the skill body. | observed | Baseline case, exercised constantly across many sessions and versions — which is also why no single version stamp fits it. |
| 2 | Trailing prose becomes the skill's arguments — `/worklog fixed the hook` → `<command-args>fixed the hook</command-args>`. | observed | First seen in earlier sessions at an unrecorded version; re-confirmed at 2.1.220 by row 4b, which is the same mechanism with a `/<name>` inside the argument text. |
| 3 | Prose *before* a command suppresses expansion entirely — `let's /pickup now` and `let's /overbaked now` both arrived as raw user text, no `<command-name>` block, no skill body. | observed | **n=2, gating eliminated.** The pair was chosen to discriminate: `pickup` is `disable-model-invocation: true`, `overbaked` is not, and both were suppressed identically — so "gated skills don't expand mid-sentence" is ruled out and position is the mechanism. Both submissions were unbackticked plain prose (checked; backtick-wrapping is not the mechanism either). **Still open:** no cold-session control — both trials ran in a session where the skill's body had already been injected by an earlier expansion, and a suppressed *negative* is weaker when the content was already resident. Also untested: prose prefixes other than the `let's … now` scaffold used both times. |
| 4 | **Every** leading command in a submission expands, in submission order, each with its full body and **no** `<command-args>` on any. | observed | Two trials: `/pickup /overbaked` (k=2, gated-then-ungated) and `/overbaked /pickup /reviewer-2` (k=3, ungated-then-gated-then-ungated). Between them, **order and gating are both eliminated** — the second trial reverses the gating order of the first and still expands all three. k=3 is the largest tested; nothing suggests a ceiling. |
| 4b | Prose *between* two commands makes the second inert: `/pickup fix this /overbaked` produced one `<command-name>` block for `pickup` with `<command-args>fix this /overbaked</command-args>`, and no `overbaked` body. | observed | n=1. **This is what resolves the row 2 / row 4 tension** — a second command is not exempt from argument capture; in row 4 there was simply no non-command token before it to start the arguments. Untested: whether an intervening token that *looks* command-ish (a bare `-`, a quote, a bullet) starts arguments the same way plain prose does. |
| 5 | Row 4 holds when the two commands are separated by a newline rather than a space. | reported | Unverifiable from inside a session: expansion discards the original whitespace, so the two submissions are byte-identical in context. Rests entirely on the tester's account. |
| 6 | Nothing warns before two sets of skill instructions land in one context. | observed | True by construction from row 4, and the honest version of a claim this file first wrote as "both bodies execute, ungated." That phrasing was category-confused: the harness does not *execute* skill bodies at all — it injects them as instructions, and whether they run is the model choosing to comply. So there is no harness-level gate to go looking for, and "a second skill that writes files" would not test the parser: it would test model compliance plus the ordinary tool-permission prompt, which applies as it always does. Cite this row for the pre-injection warning gap, and nothing for "auto-executes." |
| 7 | A command whose name is a **repo skill** shadows the Claude Code built-in of the same name: a local `resume` skill made the built-in past-session picker unreachable as `/resume`. This is why the skill is named `pickup`. | observed + reported | Version not recorded (before 2.1.220). The shadowing was seen in-session; the companion fact that `claude --resume` still worked is terminal-level, which a session cannot see — that half is the tester's account. |

**Not yet tested, in value order** (each is one submission):

- Row 3 in a **cold session**, with no prior expansion of the named skill — the last surviving confound on it, and the reason the rule is "observed" rather than settled.
- A non-prose token between two commands (`-`, `"`, a list bullet) — row 4b used plain words; the boundary the parser actually uses is untested.
- Row 5 (newline separator) by a route that doesn't depend on the tester's account — e.g. a `UserPromptSubmit` hook logging the raw payload, which *can* see the whitespace a session cannot.

When designing a probe, prefer side-effect-free commands. `/worklog /overbaked`
would have tested row 4b too, but `worklog` writes to Notion — a parser probe
should not change the world.

## The one consequence that lives in CLAUDE.md

Rows 3 and 6 combine into a single actionable rule — a **gated** skill named
mid-sentence has no invocation path from that phrasing — and that rule is stated
in `CLAUDE.md` under "A gated skill only expands at the head of a submission",
not repeated here. It survives either arm of row 3's gating confound, which is
why it is the only part promoted out of this register.

## Settings and hooks

| # | Claim | Tier | Notes |
|---|---|---|---|
| 8 | Interactive `/model` and `/effort` write straight into `~/.claude/settings.json` as the new default. | observed | Motivates the `SessionStart` re-pin hook. Version unrecorded. |
| 8b | There is no per-session opt-in for model or effort (only `fastModePerSessionOptIn`, covering fast mode alone). | inferred | A universal negative: this comes from enumerating the settings schema, not from observing an absence. A future release could add one without this row noticing. |
| 9 | `disable-model-invocation: true` does **not** reclaim description token budget — the description stays in the model's selection context. | observed | CLI 2.1.181. Known open bug: anthropics/claude-code#31935, #41417. |
| 10 | Agent frontmatter that fails to parse is dropped **silently** — the `.md` deploys and the type never registers. | observed | Classic cause: unquoted multi-line `description` containing `": "`. `lint_frontmatter()` exists for this. Version unrecorded. |
| 10b | The failure only surfaces in a *fresh* session, because the agent-type list is snapshotted at session start. | inferred | No single session can observe cross-session snapshotting; this is the explanation that fits, not a thing that was watched. |
| 11 | A ~1,536-char cap on skill `description`. | reported | CLI 2.1.181, unsourced in official docs. The lint enforces it; re-verify before relying on the exact number. CLAUDE.md defers to this row for the tier — keep them in agreement. |
| 12 | `UserPromptSubmit` hooks do **not** run for messages the user submits *mid-turn* (the ones the harness surfaces inside a running turn alongside a tool result). | observed | Found incidentally, 2026-08-04, CLI 2.1.220. With a sentinel armed, 4 user messages reached the session and only 2 appended to it — the two that didn't were both mid-turn interjections, and the two that did were ordinary between-turn submissions (191s apart, with no entries in between). The sentinel ran **before** the hook script and was payload-independent, so this is not the script exiting early on an unfamiliar payload shape: the hook command never ran at all. Still a negative result at n=2, and it does not distinguish "the event never fires" from "the event fires but user hooks are skipped for queued input". **Consequence:** any guard built on this event has a hole — a mid-turn submission bypasses it entirely. |

## When a row here turns out to be wrong

Correct it in place and move the old text into the row's confounds column with
the version that invalidated it — a claim that was true on 2.1.220 and false on
2.2.x is more useful than a silently rewritten row. If a claim graduates to
documented behavior, cite the doc URL and drop the tier.
