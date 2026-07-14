---
name: worklog
description: Capture a work-log entry to the Notion Work Journal, the talim-server cache, and a local mirror. Use whenever the user asks to log, note, record, or journal progress, a decision, or what they just did — and as the capture step invoked by /handoff.
allowed-tools: mcp__claude_ai_Notion__notion-search mcp__claude_ai_Notion__notion-fetch mcp__claude_ai_Notion__notion-create-pages mcp__claude_ai_Notion__notion-update-page Bash Read
argument-hint: "[what to log]"
catalog:
  order: 15
  summary: 'Log a work entry to the Notion Work Journal + talim-server cache + local `.ai/` mirror — the capture core invoked by `/handoff` and whenever you ask to log something.'
---

Capture one work-log entry into **three** targets. All three are best-effort —
**never fail or block the caller** if a target is unreachable; the local mirror is
the source of truth. An end-of-day cloud routine summarizes the Notion raw
entries into narrative sections, so this skill only appends; it never summarizes.

## Compose the entry

Determine what to log:
- If the caller (e.g. `/handoff`) or the user supplied text or a summary, use it.
- Otherwise, summarize the current thread of work yourself: what got done, key
  decisions, and the top next action.

Keep it tight: `summary` is 3-5 short bullets; `next` is the top 1-3 next actions.
**Redact secrets** — never put tokens, keys, passwords, or PII in the entry.

## Configuration

Two targets are configured via env vars (set in the `env` block of
`~/.claude/settings.json`, alongside the `ZOTERO_*` keys). **If a var is unset,
skip that target silently** — no personal infrastructure is hardcoded in this
skill:

- `WORKLOG_SSH_TARGET` — `user@host` for the server cache (e.g. a Tailscale host).
- `WORKLOG_NOTION_HOME` — the Notion "Work Journal" home page id (raw entries are
  appended to weekly sub-pages under it).

## 1 + 2 — Local mirror and server cache

Fill the two arrays with the composed content, then run:

```
DAY=$(date +%F)
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
ENTRY=$(printf '{"ts":"%s","project":"%s","cwd":"%s","summary":%s,"next":%s}' \
  "$(date -Iseconds)" "$PROJECT" "$PWD" \
  '["bullet one","bullet two"]' \
  '["next action one"]')
# durable local mirror (.ai/ is gitignored) — always written
mkdir -p .ai && printf '%s\n' "$ENTRY" >> ".ai/worklog-$DAY.jsonl"
# best-effort ship to server cache (non-fatal; skipped if WORKLOG_SSH_TARGET unset)
if [ -n "${WORKLOG_SSH_TARGET:-}" ]; then
  printf '%s\n' "$ENTRY" | ssh -o ConnectTimeout=6 -o BatchMode=yes \
    "$WORKLOG_SSH_TARGET" \
    "mkdir -p ~/worklog/inbox && cat >> ~/worklog/inbox/$DAY.jsonl" \
    && echo "worklog: shipped to server" \
    || echo "worklog: server unreachable — kept local copy at .ai/worklog-$DAY.jsonl"
else
  echo "worklog: WORKLOG_SSH_TARGET unset — local mirror only"
fi
```

## 3 — Append to the Notion weekly page

Use the Notion MCP tools. Skip this step silently if `WORKLOG_NOTION_HOME` is
unset or the Notion MCP is not connected — the local + server copies already
captured the entry.

- **Work Journal home page id:** the value of `$WORKLOG_NOTION_HOME`.
- **Weekly page title convention:** `Week of YYYY-MM-DD (…)`, dated to the
  **Monday** of the current week.

Steps:
1. Compute this week's Monday:
   ```!
   python3 -c "import datetime; t=datetime.date.today(); print((t-datetime.timedelta(days=t.weekday())).isoformat())" 2>/dev/null || echo "(compute Monday manually)"
   ```
2. `notion-search` for `Week of <monday>`. If no matching page exists, create it
   under the Work Journal home page (`notion-create-pages`, parent `page_id`
   above) with this content — keep **Raw entries** as the last section (the
   append relies on it being last):
   ```
   *Daily summaries appear below, newest at top. Raw per-session entries collect under **Raw entries** at the bottom until the end-of-day routine summarizes them.*

   ---

   ## 🗂️ Raw entries (unprocessed)

   *Session entries land here via `/handoff`. Cleared nightly after summarization.*
   ```
3. Append the entry with `notion-update-page` (`command: insert_content`,
   `position: {"type":"end"}`) as a single bullet:
   `- **HH:MM · <project>** — <one-line summary>. **Next:** <top next action>`

## Anti-Rationalization

| Excuse | Reality |
|---|---|
| "The server was down, so the log failed." | The local `.ai/` mirror is the source of truth — a down server or missing Notion MCP is a non-event, not a failure. Report which targets succeeded and move on. |
| "This is minor, no need to log it." | If the user asked to log it, log it. Terse is fine; skipping is not. |
| "I'll summarize the whole day into one entry." | This skill only appends a single raw entry. The nightly routine does summarization — don't pre-empt it. |
| "I'll just write to Notion, the JSON mirror is redundant." | The mirror and server copy are the durable/offline record; Notion is the readable view. Write all reachable targets. |

## Verification

- [ ] A JSON line was appended to `.ai/worklog-<today>.jsonl` locally.
- [ ] The server push reported success, or its failure was reported (not swallowed).
- [ ] The bullet appears under **🗂️ Raw entries** on the current weekly page, or the Notion step was explicitly skipped (MCP not connected).
