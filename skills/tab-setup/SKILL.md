---
name: tab-setup
description: Assign a unique high-contrast color and name to the current Claude Code session. Selects the next available color from a greedy sequence, tracks it in ~/.claude/tab-colors.json, and outputs the two commands to apply it.
argument-hint: "[optional tab name override]"
allowed-tools: Bash(bash /home/dgilford/ai-tools/tab-setup/scripts/*)
---

```bash
bash /home/dgilford/ai-tools/tab-setup/scripts/setup-linux.sh "${CLAUDE_SESSION_ID}" $ARGUMENTS
```

The script outputs `color=<name> name=<tab-name>`. Parse those values and respond with exactly this format — nothing else:

Tab set up: **{color}** / **{name}**

Run to apply:
```
/color {color}
/rename {name}
```
