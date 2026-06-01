#!/bin/bash
# Recolors and relabels all active Claude Code sessions in bulk.
# Sessions are sorted oldest-first and assigned colors from a pre-computed
# high-contrast sequence, so the longest-running session always anchors at red.

TRACKING_FILE="${HOME}/.claude/tab-colors.json"
SESSIONS_DIR="${HOME}/.claude/sessions"
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

python3 <<PYEOF > "$TMPFILE"
import json, os, glob, subprocess

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

sessions_dir = "${SESSIONS_DIR}"
tracking_file = "${TRACKING_FILE}"

sessions = []
for f in glob.glob(os.path.join(sessions_dir, "*.json")):
    try:
        data = json.load(open(f))
        pid = data.get("pid", 0)
        os.kill(pid, 0)
        sessions.append({
            "sessionId": data["sessionId"],
            "pid": pid,
            "cwd": data.get("cwd", ""),
            "name": os.path.basename(data.get("cwd", "")) or "claude",
            "startedAt": data.get("startedAt", 0),
        })
    except Exception:
        pass

if not sessions:
    raise SystemExit(0)

sessions.sort(key=lambda s: s["startedAt"])

assignments = []
for i, session in enumerate(sessions):
    color = SEQUENCE[i % len(SEQUENCE)]
    r, g, b = COLORS[color]
    try:
        tty = subprocess.check_output(
            ["ps", "-o", "tty=", "-p", str(session["pid"])],
            stderr=subprocess.DEVNULL
        ).decode().strip()
    except Exception:
        tty = ""
    assignments.append({**session, "color": color, "r": r, "g": g, "b": b, "tty": tty})

tracking = {
    a["sessionId"]: {"color": a["color"], "pid": a["pid"], "cwd": a["cwd"], "name": a["name"]}
    for a in assignments
}
with open(tracking_file, "w") as f:
    json.dump(tracking, f, indent=2)

for a in assignments:
    print(f"{a['tty']}|{a['r']}|{a['g']}|{a['b']}|{a['name']}|{a['color']}")
PYEOF

if [[ ! -s "$TMPFILE" ]]; then
  echo "no active sessions found"
  exit 0
fi

COUNT=0
RESULTS=""

while IFS='|' read -r tty r g b name color; do
  [[ -z "$tty" || "$tty" == "??" ]] && continue
  DEV="/dev/$tty"
  [[ ! -w "$DEV" ]] && continue

  {
    printf '\033]6;1;bg;red;brightness;%d\a'   "$r"
    printf '\033]6;1;bg;green;brightness;%d\a' "$g"
    printf '\033]6;1;bg;blue;brightness;%d\a'  "$b"
  } > "$DEV"

  osascript - "$DEV" "$name" "$color" <<'ASEOF' &
on run argv
  set ttyDevice to item 1 of argv
  set tabName to item 2 of argv
  set tabColor to item 3 of argv
  delay 2
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

  COUNT=$((COUNT + 1))
  RESULTS="${RESULTS}  [${color}] ${name} (${tty})\n"

done < "$TMPFILE"

echo "Synced ${COUNT} sessions:"
printf "%b" "$RESULTS"
