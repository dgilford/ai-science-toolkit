---
name: briefly
description: Make this reply brief — the answer only, sized to the question. Use when the user writes /briefly anywhere in a prompt, or explicitly asks to keep it brief or for a TL;DR.
argument-hint: "[question] [length, e.g. '1 line' | '50 words']"
catalog:
  order: 75
  summary: 'Cap the length and detail of a reply — the answer only, sized to the question. Works mid-prompt.'
---

Answer **briefly**, for this reply only.

**The question** is everything the user wrote, minus `/briefly` itself — don't trust command arguments to hold it (stacked with another skill, `/briefly` can receive that skill's arguments). An explicit length ("1 line", "50 words", "3 bullets") overrides the defaults below.

**With another skill:** wherever `/briefly` appears — before, after, or inside another command's arguments — it caps only your reply's prose. Run the other skill's steps in full, and never shorten content that skill writes (log entries, files, commits); a literal `/briefly` in such content stays verbatim.

## Default budget (pick by question type)

| Question | Budget |
|---|---|
| Fact, yes/no, lookup | 1–2 sentences. Yes/no leads with the word. |
| "How do I…" / explain | ≤ 5 bullets or ~80 words |
| Choice / design / compare | Recommendation + ≤ 3 reasons. No option survey. |
| Code | Minimal snippet, ≤ 1 line of prose around it |
| Review / debug finding | Top 1–3 issues, most severe first |

The budget is a ceiling, not a target. When unsure, take the smaller one.

## Cut
- Preamble, restating the question, closing recaps, offers of further help.
- Headers and sections — plain sentences or a short list instead (this overrides house-style section headers).
- Secondary caveats; background the user already has.
- Exploration beyond what the answer needs — fewer tool calls, not just fewer words.

## Keep
- **At most one caveat** — the one that would change the answer or its interpretation (a baseline, a sign convention, a NaN/masking trap). One clause, not a paragraph. A second caveat goes in the closing "Skipped:" line, not the body.
- Uncertainty when present: "unsure; likely X".
- **Length is capped, rigor isn't:** verify what the answer depends on.

If something material was cut, end with **one** line naming it (e.g. "Skipped: the 2-D case.").
