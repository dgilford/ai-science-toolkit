#!/usr/bin/env bash
# Claude Code status line: 🪟 context · 🤖 model · 🪨 effort · ⏰ 5h window
# Deployed to ~/.claude/statusline-command.sh by scripts/sync.sh push.
# Referenced from settings.json via:  "statusLine": {"type":"command","command":"bash ~/.claude/statusline-command.sh"}

input=$(cat)

# Resolve jq without trusting PATH.
#
# On Windows this is not hypothetical: `winget install jqlang.jq` writes the new
# directory to the registry PATH, but an already-running Claude Code keeps the
# environment it launched with, so the status line's bash inherits a PATH with no
# jq on it. winget also creates no shim in WinGet\Links for this package — the
# binary only exists under a hashed Packages\jqlang.jq_*\ directory. The result
# was every field silently empty: "🪟 Context: -- | 🤖".
JQ=""
if command -v jq >/dev/null 2>&1; then
  JQ="jq"
else
  for _cand in \
    "$HOME"/AppData/Local/Microsoft/WinGet/Links/jq.exe \
    "$HOME"/AppData/Local/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe \
    /c/ProgramData/chocolatey/bin/jq.exe \
    "$HOME"/scoop/shims/jq.exe \
    /usr/bin/jq /usr/local/bin/jq /opt/homebrew/bin/jq
  do
    if [ -x "$_cand" ]; then JQ="$_cand"; break; fi
  done
fi

# Degrade loudly. A blank status line reads as "no data" and hides the cause;
# this says what to fix.
if [ -z "$JQ" ]; then
  printf '%s' "🪟 status line needs jq — install it and restart Claude Code"
  exit 0
fi

# Extract all four fields in a single jq pass. This used to be four separate
# `jq` invocations — nearly free on Linux, but not on Windows: measured on
# Windows 11, bash spawn alone is ~36 ms while each additional jq inside Git
# Bash costs ~70 ms, taking the whole render to ~316 ms against a ~300 ms
# refresh cadence, so the status line never finished before the next was due.
# One pass is ~112 ms. Fields, in order: context · model · effort · 5h-window.
#
# Two non-obvious constraints, both learned by shipping the wrong thing:
#   1. The separator must NOT be tab. Tab is an IFS *whitespace* character, so
#      bash collapses runs of it and an absent middle field silently shifts
#      every later value left — an absent `effort` renders the 5h percentage as
#      the effort level. US (\u001f) is not IFS whitespace, so empty fields
#      survive. Write it as a jq \u escape, never as a literal control byte.
#   2. Keep the jq program on ONE line. This file is checked out CRLF on
#      Windows, and a multi-line jq program carries those CRs into the values.
_fields=$(echo "$input" | "$JQ" -r '[.context_window.used_percentage // "", .model.display_name // "", .effort.level // "", .rate_limits.five_hour.used_percentage // ""] | join("\u001f")')
IFS=$'\x1f' read -r used_pct model effort five_hr <<< "$_fields"

# --- Emoji cues per segment: 🪟 context · 🤖 model · 🪨 effort · ⏰ 5h ---
# --- Build context segment: "🪟 Context: 28% used (72% remaining)" ---
# When remaining drops below 60%, the "(X% remaining)" glows salmon (bold truecolor).
SALMON=$'\033[1;38;2;250;128;114m'
GREEN=$'\033[1;38;2;80;200;120m'
GOLD=$'\033[1;38;2;255;191;0m'
RED=$'\033[1;38;2;255;60;60m'
RESET=$'\033[0m'
if [ -n "$used_pct" ]; then
  used_fmt=$(printf "%.0f" "$used_pct")
  remaining_fmt=$((100 - used_fmt))
  if [ "$remaining_fmt" -lt 60 ]; then
    remaining_part="${SALMON}(${remaining_fmt}% remaining)${RESET}"
  else
    remaining_part="(${remaining_fmt}% remaining)"
  fi
  ctx_segment="🪟 Context: ${used_fmt}% used ${remaining_part}"
else
  ctx_segment="🪟 Context: --"
fi

# --- Assemble output: 🪟 Context | 🤖 model | 🪨 effort | ⏰ 5h ---
out="${ctx_segment} | 🤖 ${model}"
if [ -n "$effort" ]; then
  out="${out} | 🪨 effort: ${effort}"
fi
if [ -n "$five_hr" ]; then
  five_fmt=$(printf "%.0f" "$five_hr")
  # Escalate color with usage: green ≥50%, golden ≥75%, bright red ≥90%.
  if [ "$five_fmt" -ge 90 ]; then
    five_part="${RED}${five_fmt}%${RESET}"
  elif [ "$five_fmt" -ge 75 ]; then
    five_part="${GOLD}${five_fmt}%${RESET}"
  elif [ "$five_fmt" -ge 50 ]; then
    five_part="${GREEN}${five_fmt}%${RESET}"
  else
    five_part="${five_fmt}%"
  fi
  out="${out} | ⏰ 5h: ${five_part}"
fi

printf "%s" "$out"
