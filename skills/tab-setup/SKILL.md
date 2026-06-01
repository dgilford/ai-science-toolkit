---
name: tab-setup
description: Assign a unique high-contrast color and name to the current Claude Code session banner. Writes agent-color and custom-title to the live transcript so the banner updates immediately. Tracks assignments across sessions in ~/.claude/tab-colors.json. Use "all" to recolor every active session at once.
argument-hint: "[all | optional tab name override]"
allowed-tools: Bash(bash /home/dgilford/ai-tools/tab-setup/scripts/*)
---

Set up this session's color and name:

```bash
bash /home/dgilford/ai-tools/tab-setup/scripts/setup-linux.sh "${CLAUDE_SESSION_ID}" $ARGUMENTS
```

The script output is one line: `color=<name> name=<tab-name>`.
Report to the user: "Tab set up: **<color>** / **<name>**"
