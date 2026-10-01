#!/usr/bin/env bash
# Smoke test for scripts/hook-briefly.sh: fires on /briefly anywhere except
# among the leading slash commands (which the CLI expands); never exits nonzero.
set -uo pipefail

HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/hook-briefly.sh"
failures=0

expect() {  # expect <fire|silent> <prompt>
  local out rc
  out=$(printf '%s' "$2" | jq -Rs '{prompt: .}' | bash "$HOOK"); rc=$?
  if [ "$rc" -ne 0 ]; then echo "  ✗ rc=$rc: $2"; failures=$((failures + 1)); return; fi
  case "$1:$out" in
    fire:*"Answer **briefly**"*) printf '%s' "$out" | jq -e .hookSpecificOutput.additionalContext >/dev/null \
      && echo "  ✓ $1: $2" || { echo "  ✗ not valid JSON: $2"; failures=$((failures + 1)); } ;;
    silent:) echo "  ✓ $1: $2" ;;
    *) echo "  ✗ expected $1: $2"; failures=$((failures + 1)) ;;
  esac
}

expect fire   'how do I wrap longitudes /briefly'
expect fire   'why NaN? /briefly.'
expect fire   $'first line\n/briefly second'
expect silent '/briefly what is a PR'
expect fire   '/overbaked skills/x.md /briefly'
expect silent '/overbaked /briefly skills/x.md'
expect silent '  /briefly what is a PR'
expect silent 'see a/briefly or /brieflyx'
expect silent 'no command here'
expect silent $'see this:\n<pasted_content id="ab12">\nwhat is 2+2 /briefly\n</pasted_content id="ab12">\nthoughts?'
expect fire   $'<pasted_content id="ab12">\nlog\n</pasted_content id="ab12">\nsummarize /briefly'

[ "$failures" -eq 0 ] || { echo "$failures failure(s)"; exit 1; }
