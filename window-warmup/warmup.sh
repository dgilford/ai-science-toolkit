#!/bin/zsh
# Window warmup — anchors the 5-hour Claude usage window with a 1-token Haiku ping.
# Run by launchd (com.dgilford.window-warmup) at ~5/10/15:00 ET on weekdays; WakeSystem
# wakes the sleeping Mac to fire it. See window-warmup/README.md for the why.

LOG="${HOME}/.claude/window-warmup.log"

# Guarantee subscription billing, never API. ANTHROPIC_API_KEY takes precedence over the
# logged-in OAuth token, so unset it defensively (mirrors the GH workflow's caution).
unset ANTHROPIC_API_KEY

# launchd hands jobs a minimal PATH — set one that finds the native claude install.
export PATH="${HOME}/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

ts() { date '+%Y-%m-%dT%H:%M:%S%z'; }

{
  echo "[$(ts)] warmup start (pid $$)"
  "${HOME}/.local/bin/claude" -p "Say 'Alláh-u-Abhá'." --model haiku --no-session-persistence
  echo "[$(ts)] warmup exit=$?"
} >> "${LOG}" 2>&1
