#!/usr/bin/env bash
# Smoke tests for the transcript parsers in scripts/lib/ai-sessions/ and
# vscode-extension/lib/session-status.js. These parse undocumented,
# version-dependent formats (Claude/Codex session JSONL, the tab-setup
# extension's sessions-dir schema) that can break silently on a Claude Code
# version bump. Run against tests/fixtures/ so a format change is caught here
# instead of at "ai-sessions shows nothing" in someone's actual shell.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURES="$REPO_DIR/tests/fixtures"
LIB="$REPO_DIR/scripts/lib/ai-sessions"

failures=0
check() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    echo "  ✓ $desc"
  else
    echo "  ✗ $desc"
    echo "      expected: $expected"
    echo "      actual:   $actual"
    failures=$((failures + 1))
  fi
}

echo "claude-description.py"
out=$(python3 "$LIB/claude-description.py" "$FIXTURES/claude-transcript-recap.jsonl")
check "prefers away_summary recap, strips the config hint" \
  "Debugging the login redirect loop; found the root cause in the session cookie check" "$out"

out=$(python3 "$LIB/claude-description.py" "$FIXTURES/claude-transcript-fallback.jsonl")
check "falls back to last user message, skips tool-result turns, strips XML tags" \
  "review the auth module for security issues" "$out"

echo "codex-session-id.py / codex-description.py"
SANDBOX=$(mktemp -d)
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/.codex/sessions"
cp "$FIXTURES/codex-session.jsonl" "$SANDBOX/.codex/sessions/"
cp "$FIXTURES/codex-session-noindex.jsonl" "$SANDBOX/.codex/sessions/"
cp "$FIXTURES/codex-session-index.jsonl" "$SANDBOX/.codex/session_index.jsonl"

out=$(HOME="$SANDBOX" python3 "$LIB/codex-session-id.py" "/Users/dgilford/Projects/ai-science-toolkit")
check "finds session id by matching cwd" "codex-fixture-session-id" "$out"

out=$(HOME="$SANDBOX" python3 "$LIB/codex-session-id.py" "/no/such/cwd")
check "no match on unknown cwd prints nothing" "" "$out"

out=$(HOME="$SANDBOX" python3 "$LIB/codex-description.py" "codex-fixture-session-id")
check "prefers session_index thread_name over transcript" "Add retry logic to fetch helper" "$out"

out=$(HOME="$SANDBOX" python3 "$LIB/codex-description.py" "codex-fixture-noindex-id")
check "falls back to transcript user_message when not in session_index" \
  "fallback description straight from the transcript" "$out"

if command -v node >/dev/null 2>&1; then
  echo "session-status.js"
  out=$(node "$REPO_DIR/tests/smoke_test_session_status.js")
  check "readSessionStatus (busy/idle/missing fixtures)" "PASS" "$out"
else
  echo "  (skipped: node not installed)"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All parser smoke tests passed"
