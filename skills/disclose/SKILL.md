---
name: disclose
description: Estimate the AI spectrum of involvement (0–10, MediaWise/Poynter) for a deliverable about to be shared internally or publicly, then have the user confirm or revise it and emit a content-disclosure line. Use when a shareable piece (doc, Slack message, post, figure, report, artifact) is finished, or when the user asks for an AI disclosure.
allowed-tools: Bash Read Write Grep Glob
argument-hint: "[path | \"last message\" | pasted text] [--no-ledger]"
catalog:
  order: 82
  summary: 'Estimate the AI spectrum of involvement (0–10, after [MediaWise/Poynter](https://www.youtube.com/watch?v=vmZLaXgjPCw)) for a shareable deliverable, have the user confirm or revise it, and emit a content-disclosure line naming the model''s role. Logs to `.ai/disclosures.jsonl`.'
---

You estimate how much Claude contributed to one deliverable, show the evidence, and
**hand the number to the user to confirm or revise.**

## Live context

```!
echo "author: $(git config user.name 2>/dev/null || echo '(unset — ask)')"
root="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$root" ] && git check-ignore -q "$root/.ai/disclosures.jsonl"; then
  echo "ledger: enabled ($root/.ai/disclosures.jsonl)"
else
  echo "ledger: disabled (not a git repo, or .ai/ not gitignored)"
fi
```

## Anti-Rationalization (hard gate)

**Do not emit a final disclosure line until the user has replied with a rating.**
Show the estimate, ask, stop. One question, one turn.

**Headless / unattended runs** (no user to answer): log the estimate with
`user_soi: null`, `user_reply: null`, and no statement; emit no disclosure line.
`/handoff` surfaces it as unrated later.

| Excuse | Why it doesn't hold |
|---|---|
| "My estimate is well-evidenced, just use it" — or "the session shows Claude wrote it all, so 9–10" | The user can see work you can't: drafts elsewhere, edits after pasting, pasted text that is their own prior draft. Their number ships. |
| "It's obviously 0 / obviously 10" | Still ask — a one-word reply costs nothing; a wrong public disclosure does. |
| "The user is busy, I'll fill it in" | An unconfirmed rating is a fabricated record. Leave it unrated instead. |

## Scale (0–10)

Anchors from MediaWise's *AI and Your Audience: Disclosing AI* (Poynter), as relayed
by the user — **these four are the source's:**

| SOI | Anchor |
|---|---|
| 0 | No AI involvement |
| 1 | Very little AI involvement |
| 5 | Human and AI working together as collaborators |
| 10 | AI did all the work after a prompt; no human in the loop after that |

Intermediate guidance — **interpolation, not from the source; label it so if asked:**

- **2–4:** human originates the ideas and writes the substance; AI assists narrowly
  (brainstorming, lit search, line edits, code snippets the human integrated).
- **6–9:** AI produces most of the substance (drafting, analysis, structure); the
  human directs, reviews, and edits. Less human intervention → higher number.
  9 = a small amount of human intervention (a few edits or corrections).
  10 = no intervention after the prompt — reading or glancing at it without
  changing anything still counts as 10.

## Estimate

Identify the artifact (the argument, or the most recent shareable thing in this
session). Then assess from **transcript evidence only**, per role:

| Role | Question | Evidence |
|---|---|---|
| Ideation | Who originated the framing, claims, structure? | First appearance in the conversation |
| Drafting | What share of the surviving text did Claude write vs. the user write or paste? | Compare final text to turns |
| Analysis / code | Who designed the method; who ran it? (debugging, pipelines, wrangling, tests, derivations) | Tool calls vs. user-supplied results |
| Editing | Line edits only, or restructuring? | Diff of what changed after Claude touched it |
| Review / critique | Did Claude evaluate the user's work (code, figure, methods, claim, manuscript)? | Findings the user acted on |
| Research / synthesis | Did Claude extract, summarize, reconcile, or synthesize sources? Did the user verify against the sources? | Tool calls to sources; user checks |
| Human intervention | Did the user change the output after the prompt, and how much? | User turns after the last draft |

No numeric weights; **weight roles by what the deliverable is:** for prose, ideation
and drafting carry it; for code or analysis, method design and implementation; for
research products, synthesis — unverified counts for more than verified.
**Review pulls SOI lower** than producing the same work would: the deliverable stays
the user's, so weigh how much the critique changed it, not how long the critique was.

**Blind spot:** you see only this session, so prior work the user brought in makes
you overstate Claude's share.

## Ask

Present, then stop:

```
Artifact: <!-- path or short label -->
Claude's role: <!-- roles, e.g. "brainstorming and line editing" -->
Evidence:
- <!-- one bullet per role that mattered, 2–4 total -->
Estimated SOI: <!-- n --> (<!-- one-line reason -->)
Human intervention: <!-- what the user changed after the prompt, or "none seen" -->
Blind spot: session-only view; prior or later work not counted.

Confirm, or give your rating (0–10) and any role corrections.
```

## Disclosure line

After the user replies, write the line with their rating and roles:

```
Content disclosure: <!-- Author --> prepared <!-- "a draft of" | "this" --> <!-- artifact noun -->
with <!-- roles --> assistance from Claude (spectrum of involvement: <!-- n -->).
```

Role phrases for the `roles` slot (join with "and"; list only roles that mattered):
`brainstorming` (ideation) · `drafting` · `analysis and coding` · `editing` ·
`review` · `research and synthesis`. Human intervention is never a listed role.

Adjust the verb to stay truthful at the ends of the scale:

- **0:** no line.
- **6–9:** "Claude drafted this <noun> at the direction of <Author>, who reviewed and
  edited it (spectrum of involvement: <n>)."
- **10:** "This <noun> was generated by Claude from a prompt by <Author> without
  further human editing (spectrum of involvement: 10)."

Return the line in the reply, and when the artifact is a file you can edit, **offer**
in one line to insert it — default to the end, but ask where. Insert only on a yes.

**Drift check:** before printing, confirm the line keeps the template's shape and
matches the user's number, roles, author and artifact. If they dictated wording, use
it, but flag substantive drift (missing SOI, a role added or dropped, wording that
implies more or less involvement than the number).

## Ledger

Unless `--no-ledger` or the context block says disabled, append one JSON line to
`<repo>/.ai/disclosures.jsonl` (`mkdir -p` the `.ai/` dir first; never create or edit
`.gitignore`):

```json
{"date": "YYYY-MM-DD", "artifact": "<path or short label>", "roles": ["..."], "evidence": ["<one short clause per role that mattered>"], "estimated_soi": 4, "user_soi": 3, "user_reply": "<verbatim>", "statement": "<line>"}
```

`evidence` is the estimate's supporting bullets, compressed to a clause each.
`user_reply` is the user's rating message **quoted verbatim** — it makes a skipped gate
checkable against the transcript. `user_soi` is `null` if the user declined to rate;
then write no statement either.
Best-effort: a failed write is mentioned, never blocks. Keep both SOIs; the pair is
the calibration record.

## Verification

- [ ] Estimate shown with per-role evidence and the blind-spot line, **then stopped**
- [ ] The user replied with a rating (or explicitly declined) before any disclosure line
- [ ] Disclosure line uses the **user's** number and role corrections, not the estimate
- [ ] Printed line follows the template shape, and any substantive drift from the user's reply was flagged
- [ ] Insertion offered when the artifact is an editable file
- [ ] Ledger entry carries evidence and the user's verbatim reply, or the ledger was disabled and said so
