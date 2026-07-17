# Session auto-naming and color (`tab-setup`)

Every new Claude Code session is automatically named and color-coded at boot
via the `tab-setup` skill's `SessionStart` hook (`hook-startup.sh`). The skill
is self-contained, originally developed by
[JeraldHuff/tab-setup](https://github.com/JeraldHuff/tab-setup) and forked to
[dgilford/tab-setup](https://github.com/dgilford/tab-setup).

Installing it (`bash scripts/sync.sh push`, or `bash scripts/sync.sh push
tab-setup`) deploys the skill and registers the boot hook in
`~/.claude/settings.json`.

## What the hook does

- **Name**: Haiku generates a logical 2-word adjective-noun name from the
  project directory name (e.g., `fiscal-ledger` for a finance project). Falls
  back to a deterministic wordlist hash if the API is unavailable.
- **Color**: Picks the next color not already in use by another running Claude
  session. Persists through `/clear` and `claude -c` on the same machine and
  cwd (two live sessions in one cwd can collide). Assignments live in
  `~/.claude/project-colors.json`.

## Context reminders at startup

- `[resume]` — if `.ai/HANDOFF.md` exists in the project, surfaces the
  objective and first next action so you know where you left off without
  running `/resume`
- `[env]` — reminds you to activate the project environment. Detection order:
  1. `pixi.toml` in project → `run: pixi shell`
  2. `environment.yml` in project → `activate: conda <name>`
  3. `.python-version` in project → shows Python version
  4. `.claude-session` in project → explicit override (e.g., `conda: my-env`)
  5. `~/.claude/session-init-config.json` → machine-level default (see below)

## Machine-level environment default (e.g., Jupyter server)

After `sync.sh push`, a template config is created at
`~/.claude/session-init-config.json`. Edit it to set a default env reminder for
every session on that machine:

```json
{ "default_env": "pixi shell" }
```

Leave `default_env` empty (`""`) to disable the machine-level reminder.

## Requirements

- Claude Code v2.1.152+ (floor inherited from upstream tab-setup; not
  independently verified)
- Python 3 (pre-installed on macOS/Linux)
- `ANTHROPIC_API_KEY` in `~/.claude/settings.json` `env` block (optional —
  falls back to wordlist hash if absent)

## Uninstall

```bash
python3 -c "
import json, os
p = os.path.expanduser('~/.claude/settings.json')
s = json.load(open(p))
s.get('hooks', {}).pop('SessionStart', None)
json.dump(s, open(p, 'w'), indent=2)
"
rm ~/.claude/session-init-config.json
```

## Fork maintenance

Procedures for syncing the fork with upstream, `/tab-setup update`, and
caveats: [tab-setup-maintenance.md](tab-setup-maintenance.md).
