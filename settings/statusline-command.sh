#!/usr/bin/env bash
# Claude Code status line: 🪟 context · 🤖 model · 🪨 effort · ⏰ 5h window
# Deployed to ~/.claude/statusline-command.sh by scripts/sync.sh push.
# Referenced from settings.json via:  "statusLine": {"type":"command","command":"bash ~/.claude/statusline-command.sh"}

input=$(cat)

# --- Context window ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- Model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Effort level (optional) ---
effort=$(echo "$input" | jq -r '.effort.level // empty')

# --- Rate limit: 5-hour window (Claude.ai subscribers) ---
five_hr=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

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
