---
name: retro
description: SLASH COMMAND — type /retro to run a retrospective on a coding session and propose improvements to the agent's environment (checks, pointers, steering files), never to the code. Use after a session where the agent struggled, repeated a mistake, or burned tokens finding something — or periodically, to keep CLAUDE.md from growing without bound. Report-only.
disable-model-invocation: true
allowed-tools: Bash Read Grep Glob Write
argument-hint: "[--session <id|path>] [--global] [--no-archive]"
catalog:
  order: 35
  repo_url: 'https://github.com/mattpocock/skills/tree/main/skills/engineering/retro'
  provenance:
    relation: adapted
    author: 'Matt Pocock'
    url: 'https://github.com/mattpocock'
  summary: 'Retrospective on a coding session: proposes environment fixes — a check for each repeated mistake, a pointer for each slow lookup, a cut for each no-op instruction — so CLAUDE.md gets shorter over time, not longer. Report-only.'
---

The user has asked for a **retrospective**. Look back at a coding session and propose improvements to the agent's **environment** — checks, pointers, steering files, tool access — so the next session goes better. The code the session produced is out of scope.

This is the counterweight to `evolve-claude-md`: that skill adds durable knowledge to CLAUDE.md after every session; this one finds what should have been a lint, a doc behind a pointer, or nothing at all.

**Hard gate: report-only.** Propose edits, checks, and cuts; make none of them. The user applies what they accept.

## Scope

- **Session.** The current session by default — the conversation context you already hold. With `--session <id|path>`, read that transcript instead: `~/.claude/projects/<project-slug>/<id>.jsonl` (or under `$CLAUDE_CONFIG_DIR/projects` when set). Transcripts are large; don't read one end to end. Grep for the signals in the table below (repeated reads of the same path, failed commands, retries, long search runs) and read around the hits.
- **Steering files.** The target repo's `CLAUDE.md` (or the canonical `AGENTS.md` it redirects to), its `docs/`, and any skill or hook the session used. Add `~/.claude/CLAUDE.md` with `--global`, or whenever a finding clearly belongs to every project rather than this one.
- **Existing guardrails.** Before proposing any check, read what the repo already runs: its CI workflow, pre-commit config, lint scripts, test command. A check that exists but is unwired or silently broken is the finding — not a reinvention.

## What to look for

| Category | Signal in the session | Fix shape |
|---|---|---|
| **Navigation** | The agent took several tool calls to find a file, a definition, or a fact; a hidden dependency between files surprised it | A **pointer** (one line in CLAUDE.md naming where the thing lives), or a `docs/` file the pointer targets |
| **Automated checks** | A mistake that a lint, type check, test, or filesystem rule would have caught; a repo with no guardrail at all (no CI, no pre-commit, no lint) | The cheapest **deterministic check** the repo's language and existing guardrail allow. A repo with no guardrail is itself a finding, not a neutral default |
| **Steering → check** | A CLAUDE.md rule that describes a *mechanical* pattern — a banned call, an import shape, a file-location rule, a value that must match another | Build the check; cut the prose to a pointer at the check. Reserve prose for **judgement calls** no check could substitute for |
| **Steering → docs** | A CLAUDE.md passage that is reference material — a procedure, a design history, a lessons-learned block — read in full on every session but needed in few | Move it to `docs/<topic>.md`; leave a one-line pointer |
| **No-ops** | An instruction that did not change the agent's behavior — the session followed it by default, or ignored it without consequence | Cut it. Quote the instruction and say which of the two it was |
| **Tool economy** | An expensive or repeated tool call that a script, a cached result, or a narrower query would have replaced; a tool whose definition costs more context than its use returned | Name the cheaper path |
| **Information access** | A fact the agent needed and could not reach — a log, a service, an environment variable, a file outside the repo | Name what access would have closed the gap, and its cost |

**Routing ladder.** For every finding that would touch a steering file, ask in order: (1) can a deterministic check enforce it? (2) is it reference material that belongs behind a pointer? (3) only then, is it a judgement call that earns prose? Default to the check. A rule stated in CLAUDE.md is advisory; a rule enforced by a lint is a fact.

## Output

Lead with the session in two lines: what it was doing, and the one thing that cost it the most.

Then one entry per finding, **ordered by severity** (a missing guardrail or a repeated mistake outranks a slow lookup):

```
### [category] — short label                               severity: high | med | low
Evidence: what happened in the session (quote or tool-call count; file:line for steering text)
Proposal: the concrete change — the check to add, the pointer text, the lines to cut
Cost: what applying it takes (minutes / a new script / a settings change the user must paste)
```

Close with a summary table — category, label, severity, cost — and a one-line tally of what the proposals would do to the steering file's size (lines added vs. cut). If the session surfaced nothing, say so in one line and stop; do not manufacture findings.

**Secrets and PII.** Transcripts and steering files can hold credentials, tokens, and third-party personal data. Never quote a credential into the report; name the finding without the value. The archived report inherits the sensitivity of whatever it quotes — say so when a finding quotes session text that identifies someone.

## Archive

Unless `--no-archive` was passed: after emitting the report, write it verbatim to `<repo-root>/.ai/reviews/<YYYY-MM-DD>-retro[-<session-slug>].md` (`mkdir -p "$(git rev-parse --show-toplevel)/.ai/reviews"`; suffix `-2`, `-3`… on filename collision). Best-effort — if the cwd isn't a git repo or the write fails, add a one-line note and move on; never alter the report itself. Probe the ignore with the **file path at repo root**, not the bare directory: if `git check-ignore -q "$(git rev-parse --show-toplevel)/.ai/reviews/probe.md"` exits non-zero, warn and suggest adding `.ai/` to `.gitignore`. (`git check-ignore -q .ai` false-negatives for the directory-form `.ai/` pattern whenever the directory does not yet exist.)

**Provenance header.** Prepend a YAML block to the **archived file only** (never to the report shown to the user):

```yaml
---
skill: retro
skill-version: <toolkit version>
reviewed-repo: <repo basename> @ <short SHA>[ (dirty)]
cli: <claude --version>
date: <YYYY-MM-DD>
---
```

Collect the values with:

```bash
SD="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/retro}"; SD="${SD:-$HOME/.claude/skills/retro}"
cat "$SD/.version" 2>/dev/null || echo unknown    # skill-version ("unknown" under plugin install)
git rev-parse --short HEAD 2>/dev/null || echo unknown
git status --porcelain 2>/dev/null | head -1      # non-empty → append " (dirty)"
claude --version 2>/dev/null || echo unknown
```

`.version` is written into the deployed skill dir by `sync.sh push`; it is absent under a plugin install, which is expected. Resolve any value that fails to `unknown` — never drop the key, and never let a failed lookup block or alter the archive.

## Anti-rationalization

| Excuse | Rebuttal |
|---|---|
| "The session went fine, nothing to report." | A clean session still reads every line of CLAUDE.md. Check the no-op and steering → docs rows against the file before concluding. |
| "I'll just fix the lint while I'm here." | Report-only. A proposed check the user never saw is a change to their live environment; write the proposal, not the file. |
| "This rule is too nuanced for a check." | Classify it first. "Don't call X" and "Y must equal Z" are mechanical however carefully they're worded. Only cross-file consistency and style judgement earn prose. |
| "Adding the rule to CLAUDE.md is faster than writing the check." | Faster today, and loaded into every session after. The check costs once; the prose costs forever. |
| "The transcript is too big to read." | Don't read it. Grep for the signals; read around the hits. |

## Verification

- [ ] No file outside `.ai/reviews/` was modified.
- [ ] Every proposal that touches a steering file passed the routing ladder, and the entry says which rung it landed on.
- [ ] Each "automated check" finding names the existing guardrail it builds on (or states that none exists).
- [ ] No credential or token value appears in the report.
- [ ] Findings are ordered by severity, and the closing tally states lines added vs. cut.
