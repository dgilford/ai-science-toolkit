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
| 3 | Prose *before* a command suppresses expansion entirely — `let's /pickup now` and `let's /overbaked now` both arrived as raw user text, no `<command-name>` block, no skill body. | observed | **n=4, gating, body-residency, and session position all eliminated.** The first pair was chosen to discriminate on gating: `pickup` is `disable-model-invocation: true`, `overbaked` is not, and both were suppressed identically — so "gated skills don't expand mid-sentence" is ruled out. The third trial (2026-08-04, **CLI 2.1.221**) is the cold-body control the first two lacked: `let's /overbaked now` in a session where `overbaked` had never expanded, so its body was not resident, and suppression was identical. The fourth (2026-08-04, **CLI 2.1.221**) is the cold-*session* control: `let's /pickup now` as the very first submission of a fresh session, immediately after `/clear`. Still no `<command-name>` block for `pickup` and no body — the model had to invoke it via the Skill tool. So the mechanism is **position within the submission, not position within the session.** All submissions were unbackticked plain prose (checked; backtick-wrapping is not the mechanism either). **Still open:** all four used the same `let's … now` scaffold, so phrasing is not separated from position. Minor confound on trial 4: the `/clear` that opened the session did emit its own `<command-name>` block in the same user message, so the prose was not the literal first token of the message — but `/clear` is a built-in that injects no skill body, so it cannot have supplied residency. |
| 4 | **Every** leading command in a submission expands, in submission order, each with its full body and **no** `<command-args>` on any. | observed | Two trials: `/pickup /overbaked` (k=2, gated-then-ungated) and `/overbaked /pickup /reviewer-2` (k=3, ungated-then-gated-then-ungated). Between them, **order and gating are both eliminated** — the second trial reverses the gating order of the first and still expands all three. k=3 is the largest tested; nothing suggests a ceiling. |
| 4b | Prose *between* two commands makes the second inert: `/pickup fix this /overbaked` produced one `<command-name>` block for `pickup` with `<command-args>fix this /overbaked</command-args>`, and no `overbaked` body. | observed | n=1. **This is what resolves the row 2 / row 4 tension** — a second command is not exempt from argument capture; in row 4 there was simply no non-command token before it to start the arguments. Untested: whether an intervening token that *looks* command-ish (a bare `-`, a quote, a bullet) starts arguments the same way plain prose does. |
| 5 | Row 4 holds when the two commands are separated by a newline rather than a space. | reported | Unverifiable from inside a session: expansion discards the original whitespace, so the two submissions are byte-identical in context. Rests entirely on the tester's account. |
| 6 | Nothing warns before two sets of skill instructions land in one context. | observed | True by construction from row 4, and the honest version of a claim this file first wrote as "both bodies execute, ungated." That phrasing was category-confused: the harness does not *execute* skill bodies at all — it injects them as instructions, and whether they run is the model choosing to comply. So there is no harness-level gate to go looking for, and "a second skill that writes files" would not test the parser: it would test model compliance plus the ordinary tool-permission prompt, which applies as it always does. Cite this row for the pre-injection warning gap, and nothing for "auto-executes." |
| 7 | A command whose name is a **repo skill** shadows the Claude Code built-in of the same name: a local `resume` skill made the built-in past-session picker unreachable as `/resume`. This is why the skill is named `pickup`. | observed + reported | Version not recorded (before 2.1.220). The shadowing was seen in-session; the companion fact that `claude --resume` still worked is terminal-level, which a session cannot see — that half is the tester's account. |

**Known unknowns — deliberately not being chased.** The prose prefix is still
confounded with position (all four row 3 trials used `let's … now`); the token
boundary in row 4b was only tested with plain words, not a bare `-` or a quote;
and row 5 stays `reported`. Each is one submission to test, and none of them
changes what anyone does — the actionable rule above survives either arm of all
three. Chasing them was retired on 2026-08-04 as parser archaeology: n≤4 negatives
about a closed-source parser that ships weekly, with no CI able to tell you when
they break. Fix a row when it bites in real use; don't run probes for their own
sake.

If a probe ever *is* warranted, prefer side-effect-free commands. `/worklog /overbaked`
would have tested row 4b too, but `worklog` writes to Notion — a parser probe
should not change the world.

## The one consequence that lives in CLAUDE.md

Rows 3 and 9b combine into the one actionable rule — a skill named mid-sentence
does not expand, but a **gated** one is still reachable by name through the
`Skill` tool, so what you lose is argument capture, not access. That rule is
stated in `CLAUDE.md` under "A gated skill only expands at the head of a
submission", not repeated here.

It is the only part promoted out of this register, and it survives every
confound still open on row 3. **It also spent a while stated wrongly** — as
"no invocation path from that phrasing," which row 9b falsified on 2026-08-04.
Worth remembering when deciding what else to promote: the rule that got copied
into the always-loaded file was the one claim here nobody re-tested, because it
read as settled. Prefer promoting things that fail loudly.

## Settings and hooks

| # | Claim | Tier | Notes |
|---|---|---|---|
| 8 | Interactive `/model` and `/effort` write straight into `~/.claude/settings.json` as the new default. | observed | Motivates the `SessionStart` re-pin hook. Version unrecorded. |
| 8b | There is no per-session opt-in for model or effort (only `fastModePerSessionOptIn`, covering fast mode alone). | inferred | A universal negative: this comes from enumerating the settings schema, not from observing an absence. A future release could add one without this row noticing. |
| 9 | `disable-model-invocation: true` does **not** reclaim description token budget — the description stays in the model's selection context. | observed | CLI 2.1.181. Known open bug: anthropics/claude-code#31935, #41417. |
| 9b | `disable-model-invocation: true` withholds a skill from the available-skills listing Claude selects from, but does **not** reject an explicit `Skill` call naming it. | observed | 2026-08-04, **CLI 2.1.221**. Found by accident while running the row 3 probe: `let's /pickup now` did not expand, and `Skill(pickup)` then loaded the body normally — no error. `pickup` is confirmed gated in its frontmatter, and all 11 gated skills in this repo were absent from that session's listing while all 9 ungated ones were present, so the withholding half is solid at n=11/9. **This corrects a claim `CLAUDE.md` carried until now:** that the tool "hard-rejects it (`cannot be used with Skill tool due to disable-model-invocation`)". That rejection was never observed here; it may have been true at an earlier version, or may have been inferred from the field's name and written down as fact. Either way the invocation path exists at 2.1.221, so gating is not a way to make a skill unreachable — it only stops Claude reaching for it *unprompted*. |
| 10 | Agent frontmatter that fails to parse is dropped **silently** — the `.md` deploys and the type never registers. | observed | Classic cause: unquoted multi-line `description` containing `": "`. `lint_frontmatter()` exists for this. Version unrecorded. |
| 10b | The failure only surfaces in a *fresh* session, because the agent-type list is snapshotted at session start. | inferred | No single session can observe cross-session snapshotting; this is the explanation that fits, not a thing that was watched. |
| 11 | A ~1,536-char cap on skill `description`. | reported | CLI 2.1.181, unsourced in official docs. The lint enforces it; re-verify before relying on the exact number. CLAUDE.md defers to this row for the tier — keep them in agreement. |
| 12 | `UserPromptSubmit` hooks do **not** run for messages the user submits *mid-turn* (the ones the harness surfaces inside a running turn alongside a tool result). | observed | Found incidentally, 2026-08-04, CLI 2.1.220. With a sentinel armed, 4 user messages reached the session and only 2 appended to it — the two that didn't were both mid-turn interjections, and the two that did were ordinary between-turn submissions (191s apart, with no entries in between). The sentinel ran **before** the hook script and was payload-independent, so this is not the script exiting early on an unfamiliar payload shape: the hook command never ran at all. Still a negative result at n=2, and it does not distinguish "the event never fires" from "the event fires but user hooks are skipped for queued input". **Consequence:** any guard built on this event has a hole — a mid-turn submission bypasses it entirely. |

## When a row here turns out to be wrong

Correct it in place and move the old text into the row's confounds column with
the version that invalidated it — a claim that was true on 2.1.220 and false on
2.2.x is more useful than a silently rewritten row. If a claim graduates to
documented behavior, cite the doc URL and drop the tier.
