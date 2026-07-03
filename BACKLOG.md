# Backlog

Standing list of outstanding tasks and potential improvements for this repo.
Transient session state lives in `.ai/HANDOFF.md` (gitignored, overwritten each
`/handoff`); durable tasks belong here.

## Open

- [ ] **Bug-watch routine notification channel — finish the webhook.** Routine
  `trig_01YR15V8NzaehoWj1hMMukRW` currently DMs the FIXED report to the user's Slack
  self-DM (`U0173PYR613`) as a placeholder — *lands but does not push a notification*.
  Real fix pending: a Slack **incoming webhook** (app posts → real notification).
  Webhook app is awaiting Slack admin approval. Once approved: create the webhook URL,
  swap the routine's `slack_send_message` step for a `Bash` `curl` to the webhook, and
  strip the now-unused Gmail/bioRxiv/Slack/Notion connectors from the routine.
- [ ] **Watch upstream PR #6** —
  https://github.com/JeraldHuff/tab-setup/pull/6
  (`dgilford:feat/disable-model-invocation` → `JeraldHuff:main`). Status (2026-06-19):
  still OPEN, mergeable, awaiting Jerald. After merge, fast-forward the fork's `main` and
  run `sync.sh push`. (The field is already live in the deployed `skills/tab-setup/SKILL.md`
  regardless of merge.)
- [ ] **Retire the bug-watch routine once the upstream bug lands.** The trigger is
  anthropics/claude-code#22345 closing with `state_reason == "completed"` **or** a CHANGELOG
  entry (#31935 and #41417 are already closed as duplicates of #22345 — their closure means
  nothing). Caveat: #22345 is titled as a *plugin*-skills issue, a weak proxy for the
  token-reclaim fix — on any FIXED signal, verify empirically that `disable-model-invocation`
  reclaims description token budget before revisiting the ai-tools token-budget goal and
  deleting the routine at https://claude.ai/code/routines.
- [ ] **Simplify Tier-2 health monitoring** (from `/ai-review` 2026-07-03): the monthly
  `warmup health check` routine only ever scans the current month's runs — always inside
  GitHub's ~90-day retention — so the orphan-branch heartbeat log is not load-bearing.
  Point the routine at the Actions API (trigger type, timestamp, conclusion are all in the
  run records), then delete the `Record Tier-2 heartbeat` step and the `warmup-heartbeat`
  branch. Requires editing the cloud routine, so not doable from a repo session.
- [ ] **Decide Tier 1's retirement date.** Docs promise launchd will be superseded by
  Tier 3 "once validated" — set the validation criterion (e.g. one clean month of Tier-3
  log entries) and remove the LaunchAgent + docs when it's met.
- [ ] **Generate the skill/agent catalog tables from frontmatter** (from `/ai-review`):
  the same catalog lives in CLAUDE.md, README.md, and pathfinder and has drifted twice; a
  `scripts/gen-docs.sh` regenerating the tables from `skills/*/SKILL.md` + `agents/*.md`
  frontmatter would make drift structurally impossible.
- [ ] **Add fixtures + smoke tests for the transcript parsers** (from `/ai-review`):
  `ai-sessions.sh` and `extension.js` parse undocumented, version-dependent formats
  (Claude/Codex JSONL, sessions-dir schema) that break silently when formats change.
  Capture one fixture line per format under `tests/fixtures/` and wire a smoke test into
  `.github/workflows/lint.yml`.

## Someday / explore

- [ ] **Evaluate [Backlog.md](https://github.com/MrLesk/Backlog.md) as a task-manager upgrade.**
  Markdown-native, git-tracked Kanban with an MCP server that lets Claude
  create/list/update/search tasks via tool calls (instead of hand-editing this file) —
  a strong fit for the human+AI workflow here. Deferred: overkill at the current ~handful
  of tasks, adds a global CLI dependency, and auto-writes itself into the Claude Code MCP
  config (same `settings.json` as the tab-setup hook/connectors). Revisit once task volume
  grows or Claude-managed tasks become worth the ceremony. Trial is low-risk and reversible
  (`brew install backlog-md` + `backlog init` → a removable `backlog/` dir).

## Notes

- Gmail connector is **draft-only** — no send capability exists; it cannot be used for
  unattended email notifications.
- Slack self-DMs (and self-@mentions) never generate notifications because the connector
  acts as the user. Only an independent sender (webhook/app) notifies.
- Routines can't be *deleted* via API (no delete action) — only at https://claude.ai/code/routines.
  But they CAN be *disabled* via `RemoteTrigger update` with body `{"enabled": false}`, which
  stops them firing (functionally retired, just still listed).
