# ai-tools

Global Claude Code skills for scientific computing workflows.

## Skills

| Skill | Command | Purpose |
|---|---|---|
| **handoff** | `/handoff` | Write `.ai/HANDOFF.md` at session end; auto-runs `update-claude-md` |
| **resume** | `/resume` | Reconstruct session context from `.ai/HANDOFF.md` at session start |
| **update-claude-md** | `/update-claude-md` | Promote durable session knowledge into `CLAUDE.md` |
| **grill-me** | `/grill-me` | Stress-test a plan via relentless structured questioning |
| **write-new-skill** | `/write-new-skill` | Scaffold and iterate on new Claude Code skills |

## Installation

Copy any skill into your global Claude Code skills directory:

```bash
cp -r skills/<name> ~/.claude/skills/
```

Or clone the repo and symlink:

```bash
git clone https://github.com/dgilford/ai-tools.git ~/ai-tools
ln -s ~/ai-tools/skills/<name> ~/.claude/skills/<name>
```

## Session workflow

```
/resume          # start of session — loads handoff, reports state
/handoff         # end of session — writes handoff, updates CLAUDE.md
/update-claude-md  # anytime — promote new knowledge to CLAUDE.md
```

The `.ai/` directory is repo-local (gitignored) and holds session state. Add it to `.gitignore` in any project where you use these skills.

## License

Copyright (c) 2026 Daniel Gilford

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details. You are free to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of this software, with attribution.
