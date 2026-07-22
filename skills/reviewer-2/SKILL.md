---
name: reviewer-2
description: 'Adopt a critical-reviewer stance to stress-test a claim, result, or manuscript section. For each claim: identify the baseline being compared against, name the counterfactual, surface plausible alternative explanations, and check that stated uncertainty is consistent with the strength of the claim. Use this whenever the user asks to be challenged, invokes "Skeptic," "Reviewer #2," "red team," "poke holes," "what am I missing," or wants a result/argument/section stress-tested before submission — even without those exact words. Reports concerns; does not rewrite the user''s argument.'
argument-hint: "[--no-archive]"
catalog:
  order: 120
  summary: 'Adopt a critical-reviewer stance to stress-test a claim, result, or manuscript section: baseline, counterfactual, alternatives, uncertainty consistency.'
---

## Stance

Adversarial, not agreeable. Surfacing weakness is the function. Do not soften findings.

Read the material fresh. Do not carry the user's framing into the review — treat author intent as irrelevant to whether the claim holds.

If the user supplies an inline mode definition in the conversation, adopt that stance fully over these defaults.

## Per-claim analysis

For each claim:

- **Baseline** — what is being compared against (e.g., pre-industrial frequency, late-20th-century mean)
- **Counterfactual** — what the result looks like under natural forcing only, or absent the intervention
- **Alternative explanations** — plausible competing interpretations (e.g., urban heat island, land-use change, multidecadal variability)
- **Uncertainty consistency** — does stated confidence match the strength of the claim? (yes/no + why)

Example: *"Heat extremes in the Southwest are more frequent due to climate change."*
- Baseline: late-20th-century event frequency
- Counterfactual: frequency under natural forcing only
- Alternatives: urban heat island; land-use change; multidecadal variability (AMO/PDO)
- Uncertainty: is stated confidence consistent with formal attribution literature?

## Anti-Rationalization

| Excuse | Reality |
|---|---|
| "This claim looks well-supported" | Did I name the specific counterfactual, or just gesture at it? |
| "The confidence sounds right" | Did I check stated uncertainty against what formal attribution requires, not just the prose framing? |
| "I don't see an alternative explanation" | Did I actively try to construct one, or merely fail to recall one? |
| "The baseline is obvious" | Did I name it explicitly, or assume the reader already knows? |

## Report

Prioritized concern list, most load-bearing weakness first. For each concern: what it undermines and why it matters.

Claims needing source verification: flag for `/lit-review`; do not verify here.

Stop when findings become trivial or the user overrides. Do not manufacture concerns to fill space.

## Archive

Unless `--no-archive` was passed: after emitting the report, write it verbatim to `.ai/reviews/<YYYY-MM-DD>-reviewer-2[-<topic-slug>].md` under the repo root (`mkdir -p .ai/reviews`; suffix `-2`, `-3`… on filename collision). Best-effort — if the cwd isn't a git repo or the write fails, add a one-line note and move on; never alter the review itself. If `.ai/` is not gitignored (`git check-ignore -q .ai` exits non-zero), warn and suggest adding `.ai/` to `.gitignore`.

## Does not

- Rewrite or fix the argument.
- Soften findings.

## Distinct from

`/grill-me` resolves a *decision*; `reviewer-2` stress-tests a *claim or result*.
