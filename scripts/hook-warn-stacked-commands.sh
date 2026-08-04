#!/usr/bin/env bash
# UserPromptSubmit hook: warn when a submission starts with two or more slash
# commands. They all expand — each contributes a `<command-name>` block and its
# full skill body (docs/harness-behavior.md row 4, observed); that both bodies
# then run with no per-command gate is row 6, inferred.
#
# Warn-only: emits {"systemMessage": ...}, exits 0, never rewrites the prompt.
# Never exits 2 — on this event exit 2 ERASES the user's prompt, which is far
# worse than a missed warning. Fails open on any unexpected input (no jq, bad
# stdin, unrecognized field): a hook on every prompt must not be fatal or noisy.
#
# Registration is manual per machine — see CLAUDE.md "Stacked-command warning hook".

set -uo pipefail

payload=$(cat 2>/dev/null) || exit 0
[ -n "$payload" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

# The hooks reference documents the common fields (session_id, cwd, …) but does
# not name the field carrying the user's text on this event, so try the plausible
# spellings and give up quietly if none match. Narrow this once it's documented.
prompt=$(printf '%s' "$payload" \
  | jq -r '.prompt // .user_prompt // .promptText // empty' 2>/dev/null) || exit 0
[ -n "$prompt" ] || exit 0

# Word-split the prompt to walk its leading tokens. `set -f` is essential, not
# stylistic: without it the unquoted expansion also performs PATHNAME expansion
# against the cwd, so a pasted `/*/*/*/*/*/*/*` expands to hundreds of thousands
# of paths — measured at 28s wall and 176MB before this guard — on a hook that
# runs on every prompt. Globbing off, splitting on.
set -f
count=0
for token in $prompt; do
  case "$token" in
    # A real command has no interior slash, so `/etc/hosts` and friends break the
    # run rather than inflating the count. (Plugin commands use `plugin:skill`.)
    /[a-z]*/*) break ;;
    /[a-z]*) count=$((count + 1)) ;;
    *) break ;;
  esac
done
set +f

[ "$count" -ge 2 ] || exit 0

# Only the integer count reaches the message — no prompt text is echoed back, so
# there is no path for pasted content to reach the terminal or the context.
jq -cn --argjson n "$count" '{
  systemMessage: ("Heads up: this submission starts with \($n) slash commands. Each expands into this one turn, loading its full skill body, with no per-command confirmation. If you meant only the first, cancel and resend.")
}' 2>/dev/null || exit 0
