---
name: grilling
description: Grill the user relentlessly about a plan or design, one decision at a time, until you reach shared understanding. Use when the user wants to stress-test a plan before building or uses a "grill" trigger phrase — and proactively, before any step that changes running state, allocates a shared resource (GPUs, ports, memory), edits an interdependent config, or could invalidate an earlier decision. Adapted from Matt Pocock.
catalog:
  order: 50
  repo_url: 'https://github.com/mattpocock/skills/tree/main/skills/productivity/grilling'
  provenance:
    relation: adapted
    author: 'Matt Pocock'
    url: 'https://github.com/mattpocock'
  summary: 'Grill the user relentlessly about a plan or design, one decision at a time, until shared understanding — the model-invokable core behind `/grill-me`.'
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time, waiting for feedback on each question before continuing. Asking multiple questions at once is bewildering.

If a *fact* can be found by exploring the codebase, look it up rather than asking me. The *decisions*, though, are mine — put each one to me and wait for my answer.

Do not enact the plan until I confirm we have reached a shared understanding.

## When to grill proactively

"If in doubt" is too weak a trigger — an agent handed a concrete task rarely *feels* in doubt, even when it hides consequential decisions. Grill *before acting*, not only when asked, whenever a step would:

- **change or restart a running service or process** (a training run, a server, a scheduled job);
- **allocate a shared resource** — GPUs, ports, memory, disk, a rate-limited API quota;
- **edit an interdependent config** whose blast radius you cannot fully see;
- **invalidate or contradict a decision** already made this session.

In these cases, surface the conflict explicitly and grill on how to resolve it before proceeding.
