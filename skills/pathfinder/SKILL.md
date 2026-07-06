---
name: pathfinder
description: SLASH COMMAND — type /pathfinder to get a navigable map of every skill and subagent and when to reach for each. Resolves the reviewer-2-vs-panel decision. Use when unsure which skill or agent to invoke, or when orienting a new session.
disable-model-invocation: true
catalog:
  order: 12
  summary: 'Router: a navigable map of every skill and subagent and when to reach for each; resolves the reviewer-2-vs-panel review decision.'
---

# Skill & Agent Router

Type `/pathfinder` when you need to know which skill or subagent to reach for.
Nothing here fires automatically; this is a navigation aid only.

---

## Session lifecycle

```
Start of session   →  /resume
                         ↓ (do work)
End of session     →  /handoff           writes .ai/HANDOFF.md, then calls /update-claude-md
Standalone update  →  /update-claude-md  promote session knowledge to CLAUDE.md only
```

---

## Skills — user-invoked (type the slash command explicitly)

| Skill | Command | Reach for it when… |
|---|---|---|
| resume | `/resume` | Starting a new session; reconstructs context from `.ai/HANDOFF.md` |
| handoff | `/handoff` | Ending a session or switching agents; calls `update-claude-md` internally |
| update-claude-md | `/update-claude-md` | Standalone CLAUDE.md update without a full handoff |
| grill-me | `/grill-me` | Stress-testing a plan or design before implementing |
| slack-message | `/slack-message` | Drafting an internal Slack update grounded in git context |
| tab-setup | `/tab-setup [all]` | Naming / coloring this Claude Code tab; `all` recolors every active session |
| write-new-skill | `/write-new-skill` | Scaffolding a new skill from scratch |
| ai-review | `/ai-review` | Full comprehensive repo/project review; orchestrates code-review/security-review/unstale/overbaked/reviewer-2 in parallel and adds gap-hunting + grounded ideation + prioritized synthesis. Run on fable at high+ effort |
| pathfinder | `/pathfinder` | This router |

## Skills — model-invokable (reachable by the model or another skill mid-task)

| Skill | Reach for it when… |
|---|---|
| `figure-review` | User shares or references a figure/plot and wants it checked for publication readiness |
| `lit-review` | Searching or synthesizing scientific literature; citation checks from a review flow |
| `overbaked` | Auditing any artifact for over-engineering, verbosity, or scope creep |
| `reviewer-2` | Quick generalist stress-test of a claim, result, or section (any domain) |
| `unstale` | Cleaning up dead imports, stale comments, resolved TODOs after a refactor |
| `update-claude-md` | Promoting session knowledge to CLAUDE.md (called by `handoff`; also invokable standalone) |

---

## Subagents — domain reviewer panel

Subagents are spawned with the Agent tool (`subagent_type:`), not slash commands.
All four are **review-only** (report findings; never rewrite).

| Subagent | Domain | Reach for it when… |
|---|---|---|
| `attribution-reviewer` | Climate attribution | An attribution claim, result, or draft section needs expert scrutiny (PR/OR/ChIP, storyline, D&A) |
| `meteo-reviewer` | Meteorology (AMS CCM) | A weather analysis or mechanistic argument needs dynamical / thermodynamic review |
| `stats-reviewer` | Statistics / ML | A statistical analysis, methods section, or quantitative result needs estimator/causal/inference review |
| `scicomm-reviewer` | Science communication | A public-facing product (article, press release, talk abstract) needs communication-effectiveness review |

---

## Review decision tree

```
Need a review?
│
├── Quick generalist stress-test — one skill, any domain, fast
│   → /reviewer-2
│     Baseline, counterfactual, alternatives, uncertainty consistency.
│     No domain expertise assumed.
│
├── Deep single-domain review — expert read on one dimension
│   ├── Attribution claim / result     → attribution-reviewer subagent
│   ├── Weather / synoptic mechanism   → meteo-reviewer subagent
│   ├── Statistical analysis / ML      → stats-reviewer subagent
│   └── Public-facing science product  → scicomm-reviewer subagent
│
└── Full multi-lens review — manuscript, full section, ≥2 dimensions
    → Spawn the relevant subset of the 4 subagents in a SINGLE message
      (parallel, independent — no cross-anchoring).
      Synthesize findings after all return.
      Use /reviewer-2 first if you want a fast generalist pass before the panel.
```

### When NOT to use the panel

- Single-domain question → one reviewer, not all four.
- `/reviewer-2` covers the generalist case; don't over-convene the panel for a claim check.
- `scicomm-reviewer` is for public-facing products, not internal methods or data.

### Citing literature during a review

Any reviewer can flag missing citations. To retrieve them, route to `/lit-review`
(Zotero, arxiv, bioRxiv, Google Scholar, Consensus).

---

## Composition rule (for skills that call other skills)

A user-invoked skill may call model-invokable skills; never another user-invoked one.
(Example: `handoff` → `update-claude-md`.)
