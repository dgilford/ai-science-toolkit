#!/bin/bash
# Watches a Claude process and removes its entry from the color tracking file on exit.
# Usage: watcher.sh <claude_pid> <session_id>

TARGET_PID="$1"
SESSION_ID="$2"
TRACKING_FILE="${HOME}/.claude/tab-colors.json"

[[ -z "$TARGET_PID" || -z "$SESSION_ID" ]] && exit 1

while kill -0 "$TARGET_PID" 2>/dev/null; do
  sleep 10
done

python3 - "$TRACKING_FILE" "$SESSION_ID" <<'PYEOF'
import json, sys
tracking_file, session_id = sys.argv[1:]
try:
    data = json.load(open(tracking_file))
    data.pop(session_id, None)
    json.dump(data, open(tracking_file, "w"), indent=2)
except Exception:
    pass
PYEOF
