# Per-skill configuration

Most of the toolkit works out of the box after `sync.sh push` — no env vars, no
connectors. This page covers the exceptions: what each skill needs, how to set
it up, and what happens if you don't.

Env vars go in the `env` block of `~/.claude/settings.json`:

```json
{
  "env": {
    "ZOTERO_USER_ID": "1234567",
    "ZOTERO_API_KEY": "…",
    "ZOTERO_INBOX_COLLECTION": "Inbox"
  }
}
```

"Connectors" are MCP servers connected to Claude (local servers in your MCP
config, or claude.ai connectors for cloud-authenticated services like Notion).

## Works with zero configuration

All four reviewer agents (`attribution-reviewer`, `stats-reviewer`,
`meteo-reviewer`, `scicomm-reviewer`) and these skills:

`ai-review`, `commit-batch`/`commit-batching`, `evolve-claude-md`,
`figure-review`, `grill-me`/`grilling`, `overbaked`, `pathfinder`, `repo-init`,
`resume`, `reviewer-2`, `slack-message` (drafts from git context — no Slack
connection needed), `write-new-skill`.

`unstale` needs `ruff` and `vulture` (plus `nbqa` for notebook mode) but
installs them into the project venv itself if missing.

`handoff` works standalone (writes `.ai/HANDOFF.md`, updates CLAUDE.md); its
final step invokes `worklog`, which quietly does nothing beyond a local mirror
until you configure it (below).

## `lit-review`

Searches whichever literature sources are connected and skips the rest — no
single source is required.

| Source | Needs |
|---|---|
| arxiv, Google Scholar, Zotero (read) | Local MCP servers in your MCP config |
| bioRxiv, Consensus | claude.ai connectors |
| Zotero (write — file papers into your library) | `ZOTERO_USER_ID`, `ZOTERO_API_KEY`, `ZOTERO_INBOX_COLLECTION` env vars ([get ID and key](https://www.zotero.org/settings/keys)) |

**Without config:** search still works across available sources; the "Add to
Zotero?" offer is skipped with a note telling you what to configure.

## `worklog`

Captures a work-log entry to three targets. Only the first works with zero
setup:

| Target | Needs | If unset |
|---|---|---|
| Local mirror (`.ai/worklog-YYYY-MM-DD.jsonl`) | Nothing | Always written — source of truth |
| Server cache (SSH append) | `WORKLOG_SSH_TARGET` env var (`user@host`) | Loud setup notice; entry still kept locally |
| Notion weekly journal page | `WORKLOG_NOTION_HOME` env var (Notion page id) + Notion connector on claude.ai | Loud setup notice; entry still kept locally |

The skill distinguishes **misconfiguration from transient failure**: an unset
var is reported loudly as a setup error; a configured-but-unreachable target
(server down, Notion disconnected) is best-effort and never blocks the caller.

The Notion target expects a "Work Journal" home page (whose id is
`WORKLOG_NOTION_HOME`) containing weekly sub-pages titled `Week of YYYY-MM-DD
(…)`; the skill creates the weekly page if missing.

## `tab-setup`

Works without config (deterministic wordlist names). Optional:
`ANTHROPIC_API_KEY` env var enables Haiku-generated session names. Full
details, machine-level env-reminder config, and uninstall:
[tab-setup.md](tab-setup.md).

## `figure-review --style`

The base review needs nothing. The `--style` flag applies a house style defined
in the skill's companion `CC-STYLE.md`; edit or replace that file to encode
your own organization's figure style.
