#!/usr/bin/env bash
# UserPromptSubmit hook: make a mid-prompt `/briefly` deterministic. Typed after
# prose, a slash command is not expanded (docs/harness-behavior.md row 3), so the
# `briefly` skill would run only if Claude noticed the text and called it — an
# extra round trip, and observed to fail 5 of 6 times (register row 4e). This
# hook injects the skill body as additionalContext instead.
#
# Stays silent only when `/briefly` is among the LEADING slash commands — the
# CLI expands it there (rows 1, 4). Everywhere else it fires, including inside
# another command's arguments (`/overbaked X /briefly`, row 4b), where the skill
# caps the reply's prose but never the other skill's steps or written content.
# Never exits 2 (that erases the prompt); fails open on anything odd.
# Fires for mid-turn submissions too at CLI 2.1.286 (row 12; it did not at
# 2.1.220) — the skill remains the fallback if that regresses.
#
# Registration is manual per machine — see CLAUDE.md "Briefly hook".

set -uo pipefail

payload=$(cat 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# Same field-name uncertainty as hook-warn-stacked-commands.sh.
prompt=$(printf '%s' "$payload" \
  | jq -r '.prompt // .user_prompt // .promptText // empty' 2>/dev/null) || exit 0
[ -n "$prompt" ] || exit 0

# Drop pasted blocks: a `/briefly` inside pasted text (logs, transcripts, this
# skill's own source) is content, not a request. The harness wraps pastes as
# <pasted_content id="X">…</pasted_content id="X"> in the hook payload too
# (register row 12b). Without perl, don't strip.
if command -v perl >/dev/null 2>&1; then
  prompt=$(printf '%s' "$prompt" | perl -0pe 's/<pasted_content\b[^>]*>.*?<\/pasted_content\b[^>]*>//gs' 2>/dev/null) || exit 0
fi

# Walk the leading run of slash commands (same tokenizing as
# hook-warn-stacked-commands.sh). `set -f` is load-bearing: the unquoted
# expansion would otherwise also glob against the cwd — see that script.
set -f
for token in $prompt; do
  case "$token" in
    /briefly) exit 0 ;;            # CLI already expands it
    /[a-z]*/*) break ;;            # a path, not a command
    /[a-z]*) ;;                    # another leading command; keep walking
    *) break ;;
  esac
done
set +f

# `/briefly` as a whole token: preceded by start/whitespace, not followed by a
# word character (so `/brieflyx` and `a/briefly` don't match).
printf '%s' "$prompt" | grep -Eq '(^|[[:space:]])/briefly([^[:alnum:]_-]|$)' || exit 0

# Repo copy first (this script runs from the checkout), deployed copy second.
here=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || exit 0
skill="$here/../skills/briefly/SKILL.md"
[ -r "$skill" ] || skill="$HOME/.claude/skills/briefly/SKILL.md"
[ -r "$skill" ] || exit 0

# Strip the YAML frontmatter; only the body is instructions.
body=$(awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' "$skill" 2>/dev/null) || exit 0
[ -n "$body" ] || exit 0

# additionalContext reaches Claude; systemMessage is shown to the user, so they
# can see brevity was applied without the model spending tokens announcing it.
jq -cn --arg body "$body" '{
  systemMessage: "briefly: applied to this reply",
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    additionalContext: ("The user typed /briefly in this prompt. Apply these instructions to your reply (no need to invoke the briefly skill):\n\n" + $body)
  }
}' 2>/dev/null || exit 0
