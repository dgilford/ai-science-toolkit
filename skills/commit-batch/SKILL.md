---
name: commit-batch
description: Batch the working tree into logical, single-concern commits, then commit (and push if asked) instead of one monolithic `git add -A`. Use when you type /commit-batch or want your pending changes split into clean, focused commits.
disable-model-invocation: true
catalog:
  order: 150
  summary: 'Batch the working tree into logical, single-concern commits, then commit and push if asked. Thin launcher for the model-invokable `commit-batching` core.'
---

Run a `/commit-batching` session on the current working tree.
