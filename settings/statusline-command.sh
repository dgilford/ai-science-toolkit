#!/usr/bin/env bash
# Claude Code status line: 🪟 context · 🤖 model · 🪨 effort · ⏰ 5h window
# Deployed to ~/.claude/statusline-command.sh by scripts/sync.sh push.
# Referenced from settings.json via:  "statusLine": {"type":"command","command":"bash ~/.claude/statusline-command.sh"}

input=$(cat)

# --- Context window ---
# Claude Code reports both the raw token counts and a precomputed percentage.
# Percentages alone became hard to read once windows grew to 1M tokens (a busy
# session reads "6% used"), so show absolute tokens as the headline figure.
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
tokens_used=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# --- Model ---
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Effort level (optional) ---
effort=$(echo "$input" | jq -r '.effort.level // empty')

# --- Rate limit: 5-hour window (Claude.ai subscribers) ---
five_hr=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# --- Emoji cues per segment: 🪟 context · 🤖 model · 🪨 effort · ⏰ 5h ---
SALMON=$'\033[1;38;2;250;128;114m'
GREEN=$'\033[1;38;2;80;200;120m'
GOLD=$'\033[1;38;2;255;191;0m'
RED=$'\033[1;38;2;255;60;60m'
RESET=$'\033[0m'

# Compact token counts: 158728 → 159k, 1000000 → 1.0M.
human_tokens() {
  awk -v n="$1" 'BEGIN {
    if (n >= 1000000)   printf "%.1fM", n / 1000000;
    else if (n >= 1000) printf "%.0fk", n / 1000;
    else                printf "%d", n;
  }'
}

# --- Build context segment: "🪟 Context: 159k/1.0M (16% used)" ---
# When remaining drops below 60%, the "(N% used)" glows salmon (bold truecolor).
# Falls back to the bare percentage if the token counts are missing, and to "--"
# before the first API response of a session (no usage reported yet).
if [ -n "$used_pct" ]; then
  used_fmt=$(printf "%.0f" "$used_pct")
  remaining_fmt=$((100 - used_fmt))
  if [ "$remaining_fmt" -lt 60 ]; then
    used_part="${SALMON}(${used_fmt}% used)${RESET}"
  else
    used_part="(${used_fmt}% used)"
  fi
  if [ -n "$tokens_used" ] && [ -n "$window_size" ] && [ "$window_size" != "0" ]; then
    ctx_segment="🪟 Context: $(human_tokens "$tokens_used")/$(human_tokens "$window_size") ${used_part}"
  else
    ctx_segment="🪟 Context: ${used_part}"
  fi
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
