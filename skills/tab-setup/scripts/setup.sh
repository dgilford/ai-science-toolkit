#!/bin/bash
# Sets tab color and Claude Code banner for a single session.
# Usage: setup.sh <session_id> [override_name]

SESSION_ID="${1:-unknown}"
TRACKING_FILE="${HOME}/.claude/tab-colors.json"
SESSIONS_DIR="${HOME}/.claude/sessions"

[[ ! -f "$TRACKING_FILE" ]] && echo '{}' > "$TRACKING_FILE"

TAB_NAME="${2:-$(basename "$PWD")}"

RESULT=$(python3 - "$TRACKING_FILE" "$SESSION_ID" "$SESSIONS_DIR" "$PWD" "$TAB_NAME" <<'PYEOF'
import json, sys, os, glob

# Pre-computed greedy farthest-point sequence — each step maximises RGB
# distance from all prior picks, so adjacent sessions never look similar.
SEQUENCE = ["red", "blue", "green", "pink", "purple", "cyan", "yellow", "orange"]
COLORS = {
    "red":    (220, 50,  47),
    "blue":   (38,  139, 210),
    "green":  (133, 153, 0),
    "yellow": (181, 137, 0),
    "purple": (108, 113, 196),
    "orange": (203, 75,  22),
    "pink":   (211, 54,  130),
    "cyan":   (42,  161, 152),
}

tracking_file, session_id, sessions_dir, cwd, name = sys.argv[1:]

# Look up the long-lived Claude process PID (not the bash subprocess PID)
claude_pid = None
for f in glob.glob(os.path.join(sessions_dir, "*.json")):
    try:
        data = json.load(open(f))
        if data.get("sessionId") == session_id:
            claude_pid = data.get("pid")
            break
    except Exception:
        pass

if claude_pid is None:
    print(f"error: no session found for {session_id}", file=sys.stderr)
    sys.exit(1)

try:
    tracking = json.load(open(tracking_file))
except Exception:
    tracking = {}

tracking.pop(session_id, None)

# Prune dead PIDs
live, used_colors = {}, set()
for sid, entry in tracking.items():
    try:
        os.kill(entry.get("pid", 0), 0)
        live[sid] = entry
        used_colors.add(entry.get("color", ""))
    except (OSError, ProcessLookupError):
        pass

# Claim the earliest sequence slot not already in use
chosen = next((c for c in SEQUENCE if c not in used_colors), SEQUENCE[0])

live[session_id] = {"color": chosen, "pid": claude_pid, "cwd": cwd, "name": name}
with open(tracking_file, "w") as f:
    json.dump(live, f, indent=2)

r, g, b = COLORS[chosen]
print(f"CHOSEN_COLOR={chosen}")
print(f"TAB_R={r}")
print(f"TAB_G={g}")
print(f"TAB_B={b}")
print(f"TAB_NAME={name}")
print(f"CLAUDE_PID={claude_pid}")
PYEOF
)

if [[ -z "$RESULT" ]] || echo "$RESULT" | grep -q '^error'; then
  echo "error: setup failed — $RESULT"
  exit 1
fi

eval "$RESULT"

CLAUDE_TTY=$(ps -o tty= -p "$CLAUDE_PID" 2>/dev/null | tr -d ' ')
if [[ -n "$CLAUDE_TTY" && "$CLAUDE_TTY" != "??" && -w "/dev/$CLAUDE_TTY" ]]; then
  # Set iTerm2 tab color via proprietary escape codes
  {
    printf '\033]6;1;bg;red;brightness;%d\a'   "$TAB_R"
    printf '\033]6;1;bg;green;brightness;%d\a' "$TAB_G"
    printf '\033]6;1;bg;blue;brightness;%d\a'  "$TAB_B"
  } > "/dev/$CLAUDE_TTY"

  # Inject /color and /rename after Claude finishes responding (~4s delay)
  osascript - "/dev/$CLAUDE_TTY" "$TAB_NAME" "$CHOSEN_COLOR" <<'ASEOF' &
on run argv
  set ttyDevice to item 1 of argv
  set tabName to item 2 of argv
  set tabColor to item 3 of argv
  delay 4
  try
    tell application "iTerm2"
      repeat with w in windows
        repeat with t in tabs of w
          repeat with s in sessions of t
            if tty of s = ttyDevice then
              tell s to write text "/color " & tabColor
              delay 0.3
              tell s to write text "/rename " & tabName
              return
            end if
          end repeat
        end repeat
      end repeat
    end tell
  end try
end run
ASEOF
else
  echo "warn: no writable TTY for PID $CLAUDE_PID (tty=$CLAUDE_TTY)" >&2
fi

nohup bash "$(dirname "$0")/watcher.sh" "$CLAUDE_PID" "$SESSION_ID" > /dev/null 2>&1 &

echo "color=${CHOSEN_COLOR} name=${TAB_NAME}"
