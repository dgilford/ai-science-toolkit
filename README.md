# ai-tools

Global Claude Code skills for scientific computing workflows.

## Skills

| Skill | Command | Purpose |
|---|---|---|
| **grill-me** | `/grill-me` | Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree |
| **handoff** | `/handoff` | Create or update a durable project handoff for the next AI agent/session |
| **lit-review** | `/lit-review` | Search and synthesize scientific literature from Zotero, arxiv, bioRxiv, Google Scholar, and Consensus |
| **overbaked** | `/overbaked` | Audit a document, plan, or code for over-engineering, verbosity, and scope creep |
| **resume** | `/resume` | Resume work from repo-local handoff state |
| **slack-message** | `/slack-message` | Draft an internal Slack message grounded in current project context and recent workflow |
| **tab-setup** | `/tab-setup` | Set a unique color and name for this Claude Code tab based on the current working directory |
| **update-claude-md** | `/update-claude-md` | Update CLAUDE.md with durable knowledge from the current session |
| **write-new-skill** | `/write-new-skill` | Create new Claude Code skills with proper structure and progressive disclosure |

## Installation

Clone the repo and deploy all skills:

```bash
git clone https://github.com/dgilford/ai-tools.git ~/ai-tools
cd ~/ai-tools
bash scripts/sync.sh push
```

## Syncing skills

Skills in `skills/` are the source of truth.

```bash
bash scripts/sync.sh push   # deploy skills/ → ~/.claude/skills/
bash scripts/sync.sh pull   # pull ~/.claude/skills/ → skills/
```

After `pull`, review `git diff skills/` — pull brings in all globally installed skills, including any not yet tracked here.

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
