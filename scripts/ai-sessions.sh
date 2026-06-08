#!/usr/bin/env bash
# ai-sessions — show running Claude / Codex CLI sessions with session IDs and resume commands
# Usage: ai-sessions [--recap]
#
# Install (add to ~/.zshrc or ~/.bashrc):
#   source /path/to/ai-tools/scripts/ai-sessions.sh
#
# --recap: calls `claude -p` to generate a one-line summary per claude session (~1-2s each).
#          Codex sessions always use stored thread_name or first user message (instant).

ai-sessions() {
  local do_recap=0
  [[ "$1" == "--recap" ]] && do_recap=1

  # interactive CLI sessions: current user, real tty (exclude no-tty: ? on Linux, ?? on BSD/macOS),
  # comm ends with claude/codex, skip app-server subprocs. Filtering out no-tty drops headless
  # (e.g. VS Code) and orphaned processes; restricting to the current user drops other users' procs
  # on shared hosts (whose transcripts we can't read or resume anyway).
  local pid_list pids=""
  pid_list=$(ps -u "$(id -un)" -o pid,tty,comm | awk '
    $2 != "?" && $2 != "??" && $3 ~ /claude$/ { print $1, "claude" }
    $2 != "?" && $2 != "??" && $3 ~ /codex$/  { print $1, "codex" }
  ' | grep -v "^$$ ")
  while IFS=' ' read -r pid cmd; do
    [[ -z "$pid" ]] && continue
    ps -p "$pid" -o args= 2>/dev/null | grep -q 'app-server' && continue
    pids+="$pid $cmd"$'\n'
  done <<< "$pid_list"

  if [[ -z "${pids// }" ]]; then
    echo "No Claude or Codex sessions running."
    return
  fi

  local tty started cwd session_id resume_cmd transcript description encoded dir
  echo ""
  while IFS=' ' read -r pid cmd; do
    [[ -z "$pid" ]] && continue
    tty="" ; started="" ; cwd="" ; session_id="" ; resume_cmd="" ; transcript="" ; description="" ; encoded="" ; dir=""

    tty=$(ps -p "$pid" -o tty= 2>/dev/null | tr -d ' ')
    started=$(ps -p "$pid" -o lstart= 2>/dev/null | awk '{print $2,$3,$4}')
    cwd=$(lsof -p "$pid" 2>/dev/null | awk '$4=="cwd"{print $NF}')

    if [[ "$cmd" == "claude" ]]; then
      encoded="-$(echo "$cwd" | sed 's|^/||; s|/|-|g')"
      dir="$HOME/.claude/projects/$encoded"
      # newest transcript in this cwd. The projects dir is keyed by cwd, not pid, so two live
      # sessions in the same cwd can't be told apart — both resolve to the most-recently-written one.
      transcript=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)
      session_id=$(basename "$transcript" .jsonl 2>/dev/null)
      [[ -n "$session_id" ]] \
        && resume_cmd="claude --resume $session_id" \
        || resume_cmd="claude -c  # (session ID not found)"

      if [[ -n "$transcript" ]]; then
        if (( do_recap )); then
          description=$(python3 - "$transcript" 2>/dev/null <<'PYEOF'
import sys, json
msgs = []
with open(sys.argv[1]) as f:
    for line in f:
        try:
            d = json.loads(line)
            role = d.get("type")
            if role == "user":
                c = d.get("message", {}).get("content", "")
                if isinstance(c, str) and c.strip():
                    msgs.append(("user", c.strip()))
                elif isinstance(c, list):
                    text = " ".join(x.get("text","") for x in c if x.get("type")=="text")
                    if text.strip(): msgs.append(("user", text.strip()))
            elif role == "assistant":
                c = d.get("message", {}).get("content", "")
                if isinstance(c, str) and c.strip():
                    msgs.append(("assistant", c.strip()))
                elif isinstance(c, list):
                    text = " ".join(x.get("text","") for x in c if x.get("type")=="text")
                    if text.strip(): msgs.append(("assistant", text.strip()))
        except: pass
excerpt = "\n".join(f"{r.upper()}: {t[:300]}" for r,t in msgs[-12:])
print(excerpt)
PYEOF
)
          description=$(echo "$description" | claude -p \
            "Summarize in one sentence (max 15 words) what was being worked on. Just the sentence, no preamble." \
            2>/dev/null)
        else
          # last human-typed user message (strip injected system tags, skip pure tool results)
          description=$(python3 - "$transcript" 2>/dev/null <<'PYEOF'
import sys, json, re
last = ""
with open(sys.argv[1]) as f:
    for line in f:
        try:
            d = json.loads(line)
            if d.get("type") != "user":
                continue
            c = d.get("message", {}).get("content", "")
            if isinstance(c, list):
                if all(x.get("type") == "tool_result" for x in c):
                    continue
                text = " ".join(x.get("text","") for x in c if x.get("type")=="text")
            else:
                text = c if isinstance(c, str) else ""
            text = re.sub(r'<[a-zA-Z][a-zA-Z0-9_-]*(?:\s[^>]*)?>.*?</[a-zA-Z][a-zA-Z0-9_-]*>', '', text, flags=re.DOTALL)
            text = text.strip()
            if text:
                last = text
        except: pass
if last:
    print(last[:120].replace("\n", " "))
PYEOF
)
        fi
      fi

    elif [[ "$cmd" == "codex" ]]; then
      session_id=$(python3 - "$cwd" 2>/dev/null <<'PYEOF'
import sys, json, os, glob
cwd = sys.argv[1]
base = os.path.expanduser("~/.codex/sessions")
for f in sorted(glob.glob(f"{base}/**/*.jsonl", recursive=True), reverse=True):
    try:
        d = json.loads(open(f).readline())
        if d.get("payload", {}).get("cwd") == cwd:
            print(d["payload"]["id"]); break
    except: pass
PYEOF
)
      [[ -n "$session_id" ]] \
        && resume_cmd="codex resume $session_id" \
        || resume_cmd="codex resume --last  # (session ID not found)"

      # try session_index thread_name first; fall back to first user_message in session file
      description=$(python3 - "$session_id" 2>/dev/null <<'PYEOF'
import sys, json, os, glob
sid = sys.argv[1]
idx = os.path.expanduser("~/.codex/session_index.jsonl")
try:
    with open(idx) as f:
        for line in f:
            d = json.loads(line)
            if d.get("id") == sid:
                name = d.get("thread_name", "")
                if name and not name.startswith("<bash") and not name.startswith("<local"):
                    print(name[:120]); sys.exit(0)
except: pass
base = os.path.expanduser("~/.codex/sessions")
for f in sorted(glob.glob(f"{base}/**/*.jsonl", recursive=True), reverse=True):
    try:
        first = json.loads(open(f).readline())
        if first.get("payload", {}).get("id") != sid:
            continue
        for line in open(f):
            d = json.loads(line)
            if d.get("type") == "event_msg" and d.get("payload", {}).get("type") == "user_message":
                msg = d["payload"].get("message", "").strip()
                if msg:
                    print(msg[:120].replace("\n", " ")); sys.exit(0)
    except: pass
PYEOF
)
    fi

    printf "  \033[1m%s\033[0m  pid=%-6s  tty=%-8s  %s\n" "$cmd" "$pid" "$tty" "$started"
    printf "  cwd:    %s\n" "${cwd:-unknown}"
    [[ -n "$description" ]] && printf "  \033[33m\"%s\"\033[0m\n" "$description"
    printf "  \033[2mresume: %s\033[0m\n" "$resume_cmd"
    echo ""
  done <<< "$pids"
}
