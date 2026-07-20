# Backlog

Standing list of outstanding tasks and potential improvements for this repo.
Transient session state lives in `.ai/HANDOFF.md` (gitignored, overwritten each
`/handoff`); durable tasks belong here.

## Open

- [ ] **Finish citation metadata at the v1.0.0 release cut.** Two steps tied to tagging:
  (1) before/at the tag, uncomment `version` + `date-released` in `CITATION.cff` and add
  `"version": "1.0.0"` to `.zenodo.json`; (2) after Zenodo mints the DOI, paste it into
  `CITATION.cff`'s `doi` field and add a DOI badge to `README.md` (replacing the "will be
  added at the first tagged release" line). Zenodo↔GitHub webhook is already enabled.
- [ ] **Bug-watch routine notification channel — finish the webhook.** The routine
  (ID in `.ai/routines.md`) currently DMs the FIXED report to the user's Slack
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
  reclaims description token budget before revisiting the ai-science-toolkit token-budget goal and
  deleting the routine at https://claude.ai/code/routines.

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
