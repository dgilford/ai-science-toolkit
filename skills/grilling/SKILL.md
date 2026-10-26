---
name: grilling
description: Grill the user relentlessly about a plan or design, working the decision tree in rounds along its frontier, until you reach shared understanding. Use when the user wants to stress-test a plan before building or uses a "grill" trigger phrase — and proactively, before any step that changes running state, allocates a shared resource (GPUs, ports, memory), edits an interdependent config, or could invalidate an earlier decision. Adapted from Matt Pocock.
catalog:
  order: 50
  repo_url: 'https://github.com/mattpocock/skills/tree/main/skills/productivity/grilling'
  provenance:
    relation: adapted
    author: 'Matt Pocock'
    url: 'https://github.com/mattpocock'
  summary: 'Grill the user relentlessly about a plan or design — the decision tree worked in rounds along its frontier, facts looked up rather than asked — until shared understanding. The model-invokable core behind `/grill-me`.'
---

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask *now* without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Word each question so "yes" accepts your recommended answer — except where the user has said a decision is theirs to make (a method, a baseline, a framing). There, lay the options out neutrally with the tradeoffs, recommend if asked, and don't pre-load the answer.

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a *later* round, not this one. A calling skill may fix the cadence (one question per round, a set order); honor it.

Finding *facts* is your job, never the user's. When a frontier question needs a fact from the environment (the codebase, the filesystem, a tool), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The *decisions* are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.

## When to grill proactively

"If in doubt" is too weak a trigger — an agent handed a concrete task rarely *feels* in doubt, even when it hides consequential decisions. Grill *before acting*, not only when asked, whenever a step would:

- **change or restart a running service or process** (a training run, a server, a scheduled job);
- **allocate a shared resource** — GPUs, ports, memory, disk, a rate-limited API quota;
- **edit an interdependent config** whose blast radius you cannot fully see;
- **invalidate or contradict a decision** already made this session.

In these cases, surface the conflict explicitly and grill on how to resolve it before proceeding.
