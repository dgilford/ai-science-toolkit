#!/bin/zsh
# Window warmup — anchors the 5-hour Claude usage window with a minimal one-message Haiku ping.
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
  out=$(claude -p "Say 'Alláh-u-Abhá'." --model haiku --no-session-persistence 2>&1)
  rc=$?
  printf '%s\n' "$out"
  # Mirror the Tier-2 workflow's outcome taxonomy so the local log can
  # distinguish an already-capped window (expected no-op) from a real fault.
  if [ "$rc" -eq 0 ]; then
    echo "[$(ts)] warmup exit=0 ping=success"
  elif printf '%s' "$out" | grep -qi 'session limit'; then
    echo "[$(ts)] warmup exit=$rc ping=capped (window already session-limited — no-op)"
  else
    echo "[$(ts)] warmup exit=$rc ping=failure"
  fi
} >> "${LOG}" 2>&1
