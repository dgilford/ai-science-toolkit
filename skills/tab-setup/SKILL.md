---
name: tab-setup
description: Set a unique color and name for this Claude Code tab based on the current working directory. Use "all" to recolor and relabel every active session at once.
argument-hint: "[all | optional tab name override]"
allowed-tools: Bash(bash ~/.claude/skills/tab-setup/scripts/*)
---

If `$ARGUMENTS` is `update`, pull the latest skill from its repo and re-install it:

```bash
bash ~/.claude/skills/tab-setup/scripts/update.sh
```

Report whether it updated (and from/to which commit) or was already current. Note that changes take effect on the next Claude session.

---

If `$ARGUMENTS` is `all`, run the bulk sync:

```bash
bash ~/.claude/skills/tab-setup/scripts/sync-all.sh
```

Report the output exactly as returned (list of sessions with their assigned colors and TTYs). Renames inject automatically with a short delay — no further action needed.

---

Otherwise, set up this session's tab:

```bash
bash ~/.claude/skills/tab-setup/scripts/setup.sh "${CLAUDE_SESSION_ID}" $ARGUMENTS
```

The script output is one line: `color=<name> name=<tab-name>`. Report to the user: "Tab set up: **<color>** / **<name>**". Color applies immediately; `/color` and `/rename` fire automatically in ~4 seconds.
