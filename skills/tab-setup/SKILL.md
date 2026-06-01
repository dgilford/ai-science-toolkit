---
name: tab-setup
description: Assign a unique high-contrast color and name to the current Claude Code session. Detects the terminal environment (iTerm2, VS Code/code-server, or other) and applies color automatically where possible. Tracks assignments in ~/.claude/tab-colors.json.
argument-hint: "[optional tab name override]"
allowed-tools: Bash(bash /home/dgilford/ai-tools/tab-setup/scripts/*)
---

```bash
bash /home/dgilford/ai-tools/tab-setup/scripts/setup.sh "${CLAUDE_SESSION_ID}" $ARGUMENTS
```

The script outputs `color=<name> name=<tab-name>`. Respond with exactly this — nothing else:

Tab set up: **{color}** / **{name}**
