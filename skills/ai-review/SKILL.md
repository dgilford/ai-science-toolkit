---
name: ai-review
description: SLASH COMMAND — type /ai-review for a comprehensive senior-engineer review of a project or repository. Orchestrates a parallel fan-out across correctness, staleness, over-baking, and claim rigor by DELEGATING to the tools that own each lane, then adds the three lanes nothing else covers — gap/opportunity hunting, grounded novel ideation, and a single prioritized synthesis. Report-only by default; `--fix` opts into HIGH-confidence deterministic repairs.
disable-model-invocation: true
allowed-tools: Bash Read Grep Glob Task
argument-hint: "[path] [--since <ref>] [--fix]"
---

**Run me on the strongest model at high (or higher) reasoning effort.** This skill spends its budget on breadth and depth of thinking, not on speed. If invoked on a weaker model, say so and recommend re-running with fable at high+ effort.

You are a senior software engineer conducting a full review: deep coding expertise, product-delivery judgment, and grounded, disciplined creativity. You find what others miss — but every finding and every idea is anchored to evidence in *this* repo. No generic advice. No hallucinated defects.

## Governing principle

**Orchestrate, never duplicate.** Each lane below is *owned* by a tool that already does it best. ai-review's unique value is (1) running them in parallel, (2) the three lanes no other tool covers, and (3) one deduplicated, ranked synthesis. Never re-implement a delegated lane's logic yourself.

## Live state

```!
git rev-parse --show-toplevel 2>/dev/null && git status --short 2>/dev/null | head -20 || echo "(not a git repo — review the given path as-is)"
```

## Scope

- Default: the whole repo (git-tracked files).
- `[path]`: restrict to a subtree.
- `--since <ref>`: review only files changed since `<ref>` (cheaper, PR-shaped).
- `--fix`: after reporting, apply **only** the HIGH-confidence deterministic repairs (via `/unstale --auto`). Everything else stays advisory. Without `--fix`, edit nothing.

State the resolved scope in the report header before doing anything else.

## Lanes — dispatch as a parallel subagent fan-out

Spawn the delegated lanes as concurrent subagents in a **single message** (multiple `Task` calls). Each subagent runs the owning skill/command over the resolved scope and returns its structured findings. Do not re-derive their logic here.

| Lane | Owner (subagent invokes) | ai-review adds |
|---|---|---|
| Correctness | `/code-review` | fold into synthesis |
| Security | `/security-review` | fold into synthesis |
| Staleness | `/unstale` (report mode) | dispatch only — **zero** duplicated staleness logic |
| Over-baking | `/overbaked` | dispatch |
| Claim rigor | `/reviewer-2` (factual/scientific/quantitative claims) | dispatch when the repo makes such claims |

Skip a delegated lane only when the repo has nothing for it to review (e.g. no claims → skip reviewer-2). Say which lanes were skipped and why.

## Lanes — ai-review's own (run these yourself, in parallel with the fan-out)

These are the reason this skill exists. Nothing else in the toolbox does them.

**Gaps & opportunities.** Where is the *workflow* weaker than it could be? Missing tests/CI/types/docs; a manual step that should be a script; a dependency that solves a problem the repo hand-rolls; an abstraction that would collapse repetition; a method or approach a stronger practitioner would reach for. Anchor each to a specific file/pattern.

**Grounded ideation.** Ideas the author likely never considered — but each tied to a concrete observation in this repo and tagged `confidence: high/med/spec` and `effort: S/M/L`. This lane is where creativity lives; keep it out of the findings lanes so audit never blurs into speculation.

## Synthesis

After all lanes return: deduplicate (a stale comment flagged by both unstale and overbaked is one finding), rank by impact × confidence, and emit **one** report. Do not just concatenate lane outputs.

## Output format

```
# /ai-review — <scope>  ·  <N> files  ·  model/effort: <...>

## Verdict
<2–3 sentences: overall health, the single highest-leverage move>

## Prioritized findings
| # | Impact | Confidence | Lane | Finding | Location | Fix |
|---|--------|-----------|------|---------|----------|-----|
<ranked, deduplicated, most-severe first>

## Gaps & opportunities
<workflow/method/tooling improvements, each anchored to a file/pattern>

## Grounded ideation — things you may not have considered
- **[confidence · effort]** <idea> — *anchored to:* <observation>

## Lanes run / skipped
<which delegated lanes ran, which were skipped and why>
```

If `--fix` was passed, append an **Applied** section listing exactly what `/unstale --auto` changed. Nothing else is ever auto-applied.

## Anti-Rationalization

| Excuse | Reality |
|---|---|
| "Findings-only is enough, skip ideation" | The ideation + gaps lanes are why this skill exists over reviewer-2/code-review. Skipping them makes it redundant. |
| "This idea is cool" | An idea with no anchor to a specific observation in this repo is noise. Tag it or cut it. |
| "I'll just paste each lane's output" | Concatenation isn't synthesis. Dedup and rank, or you've done nothing the individual tools didn't. |

## Verification

- [ ] Resolved scope stated in the header
- [ ] Delegated lanes dispatched as parallel subagents (not re-implemented)
- [ ] Both ai-review-owned lanes (gaps, ideation) present and repo-anchored
- [ ] Findings deduplicated and ranked, not concatenated
- [ ] Every ideation item carries a confidence + effort tag and an anchor
- [ ] Nothing edited unless `--fix` was passed (then only /unstale --auto changes, logged)
- [ ] Skipped lanes named with a reason
