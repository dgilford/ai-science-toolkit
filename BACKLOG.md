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
- [ ] **Retire the bug-watch routine once the upstream bug lands.** The trigger is
  anthropics/claude-code#22345 closing with `state_reason == "completed"` **or** a CHANGELOG
  entry (#31935 and #41417 are already closed as duplicates of #22345 — their closure means
  nothing). Caveat: #22345 is titled as a *plugin*-skills issue, a weak proxy for the
  token-reclaim fix — on any FIXED signal, verify empirically that `disable-model-invocation`
  reclaims description token budget before revisiting the ai-tools token-budget goal and
  deleting the routine at https://claude.ai/code/routines.
- [ ] **Delete the now-unused `warmup-heartbeat` orphan branch** on GitHub (the routine and
  workflow no longer write to it as of 2026-07-06; the branch itself isn't deletable from a
  repo session).
- [ ] **Retire Tier 1 (macOS launchd) and renumber tiers.** Tier 2 (GitHub workflow_dispatch)
  becomes Tier 1; Tier 3 (remote server cron) becomes Tier 2. Uninstall the LaunchAgent
  (`launchctl bootout gui/$(id -u)/com.dgilford.window-warmup`), remove
  `window-warmup/install.sh`'s launchd-specific bits, and update all docs/refs (CLAUDE.md,
  window-warmup/README.md, .ai/routines.md). The private `talim-server` repo also has its own
  Tier-3 references that need the same renumbering — out of scope for a repo session here.
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
