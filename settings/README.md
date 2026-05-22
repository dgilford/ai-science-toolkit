# Settings

`settings.json` — global Claude Code settings. Safe to commit; contains no secrets or machine-specific paths.

`settings.local.json` — machine-specific permissions and allowed commands. Gitignored. To back it up manually:

```bash
cp ~/.claude/settings.local.json ~/ai-tools/settings/settings.local.json
```

To restore on a new machine:

```bash
cp settings/settings.json ~/.claude/settings.json
cp settings/settings.local.json ~/.claude/settings.local.json  # if backed up
```
