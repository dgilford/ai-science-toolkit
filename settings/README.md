# Settings

`settings.json` — global Claude Code settings. Safe to commit; contains no secrets or machine-specific paths.

`statusline-command.sh` — the status-line (footer) script. Renders `Context: X% used (Y% remaining) | Model | effort: N | 5h: Z%`, with the remaining-context figure glowing salmon below 60%. `scripts/sync.sh push` deploys it to `~/.claude/statusline-command.sh` and adds the `statusLine` block to the live `~/.claude/settings.json` if absent (non-destructive — same merge as the SessionStart hook). To propagate to another environment, just run `bash scripts/sync.sh push` there.

`settings.local.json` — machine-specific permissions and allowed commands. Gitignored. To back it up manually:

```bash
cp ~/.claude/settings.local.json ~/Projects/ai-tools/settings/settings.local.json
```

To restore on a **new** machine (no existing `~/.claude/settings.json`):

```bash
cp settings/settings.json ~/.claude/settings.json
cp settings/settings.local.json ~/.claude/settings.local.json  # if backed up
bash scripts/sync.sh push   # re-registers the SessionStart hook the copy doesn't carry
```

**Do not run the `cp` over an existing `~/.claude/settings.json`** — the live file carries an
`env` block (API keys, Zotero credentials) and registered hooks that the committed copy
deliberately omits; overwriting destroys them. On an existing machine, merge the keys you
want by hand instead.
