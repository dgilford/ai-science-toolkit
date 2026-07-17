# Repository layout

A tour of what lives where. For install and usage, see the [README](../README.md).

- `AGENTS.md` — Codex entry point. It points Codex at `CLAUDE.md` for shared
  durable repo guidance.
- `CLAUDE.md` — shared source of truth for repository workflow notes,
  skill-development conventions, sync behavior, and session lifecycle.
- `BACKLOG.md` — durable in-repo task tracker (open tasks, someday/explore,
  connector notes). Transient per-session state lives in the gitignored `.ai/`.
- `agents/` — source copies of Claude Code subagent personas. Edit here first,
  then deploy with `scripts/sync.sh push` (syncs to `~/.claude/agents/`).
- `skills/` — source copies of Claude Code skills. Edit here first, then deploy
  with `scripts/sync.sh push` (syncs to `~/.claude/skills/`).
- `scripts/sync.sh` — deploys skills and agents (all of them, or just the ones
  you name), syncs the external `tab-setup` skill, and registers the startup
  hook. See [Installation](../README.md#installation).
- `scripts/ai-sessions.sh` — shell function for listing live Claude and Codex
  CLI sessions with resume commands; parses transcripts via the standalone
  scripts in `scripts/lib/ai-sessions/`.
- `scripts/gen-docs.sh` — regenerates the skill/agent catalog tables in
  CLAUDE.md and README.md from `catalog:` frontmatter (see CLAUDE.md).
- `tests/` — fixtures and smoke tests for the transcript/session-status
  parsers (`ai-sessions.sh`'s Python helpers, the VS Code extension's
  session-status reader) — undocumented, version-dependent formats that can
  break silently on a Claude Code version bump. Run with
  `bash tests/smoke_test_parsers.sh`; wired into `lint.yml`.
- `templates/` — reusable scaffolds (e.g. `CLAUDE_scientific_python.md`, a
  fill-in-the-blanks starter CLAUDE.md for new scientific-Python projects).
- `settings/` — commit-safe global Claude Code settings plus restore notes.
  Machine-local `settings.local.json` backups stay gitignored.
- `evaluations/` — written evaluations of external AI tooling considered for
  this workflow (e.g. `ruflo.md`).
- `docs/` — user and maintainer documentation (this file, per-skill
  [configuration](configuration.md), [tab-setup details](tab-setup.md), fork
  maintenance runbooks).
- `window-warmup/` — assets for a scheduled `claude -p` "warmup" that anchors
  the 5-hour usage window on weekdays; rationale and setup in
  `window-warmup/README.md`.
- `.github/workflows/` — GitHub Actions. `window-warmup.yml` runs the weekday
  warmup (triggered by an external scheduler via `workflow_dispatch`; the
  `schedule:` cron is a coarse backup — see `window-warmup/README.md`).
  `lint.yml` checks skill and agent frontmatter, catalog-table drift,
  ShellCheck, and the `tests/` parser smoke tests on every push/PR.
- `tab-setup/` — external skill checkout from
  [dgilford/tab-setup](https://github.com/dgilford/tab-setup); `sync.sh push`
  refreshes this before copying its scripts into `skills/tab-setup/`. Fork
  maintenance: [tab-setup-maintenance.md](tab-setup-maintenance.md).
- `vscode-extension/` — small helper extension for applying pending Claude tab
  colors/names in VS Code-compatible remote servers.
