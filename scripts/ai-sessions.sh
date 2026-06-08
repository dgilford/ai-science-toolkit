#!/usr/bin/env bash
# ai-sessions — show running Claude / Codex CLI sessions with session IDs and resume commands
# Usage: ai-sessions [--recap]
#
# Install (add to ~/.zshrc or ~/.bashrc):
#   source /path/to/ai-tools/scripts/ai-sessions.sh
#
# --recap: copies Claude's own "* recap:" block verbatim if present (the system/away_summary
#          it writes when you step away); otherwise generates one in the same style via a
#          headless `claude -p` call with hooks disabled (so it never triggers tab-setup).
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
          # 1) Copy Claude's own "* recap:" block verbatim if it exists: the latest
          #    system/away_summary record, minus the "(disable recaps in /config)" UI hint.
          description=$(python3 - "$transcript" 2>/dev/null <<'PYEOF'
import sys, json, re
recap = ""
for line in open(sys.argv[1]):
    try:
        d = json.loads(line)
    except:
        continue
    if d.get("type") == "system" and d.get("subtype") == "away_summary":
        c = (d.get("content") or "").strip()
        if c:
            recap = c
if recap:
    recap = re.sub(r'\s*\(disable recaps in /config\)\s*$', '', recap)
    print(recap.replace("\n", " ").strip())
PYEOF
)
          # 2) No recap yet — generate one in the same style from the recent transcript.
          #    disableAllHooks keeps this throwaway call from triggering SessionStart/tab-setup;
          #    --settings preserves OAuth auth (unlike --bare, which skips settings entirely).
          if [[ -z "$description" ]]; then
            description=$(python3 - "$transcript" 2>/dev/null <<'PYEOF' | claude -p --settings '{"disableAllHooks": true}' "Write a recap of this Claude Code session in EXACTLY this style: 'Goal: <one sentence>. <one sentence of current state>. Next: <the pending decision or step>.' 2-3 sentences, no preamble, no markdown." 2>/dev/null
import sys, json
msgs = []
for line in open(sys.argv[1]):
    try:
        d = json.loads(line)
    except:
        continue
    role = d.get("type")
    if role not in ("user", "assistant"):
        continue
    c = d.get("message", {}).get("content", "")
    if isinstance(c, list):
        text = " ".join(x.get("text", "") for x in c if x.get("type") == "text")
    else:
        text = c if isinstance(c, str) else ""
    text = text.strip()
    if text:
        msgs.append(f"{role.upper()}: {text[:300]}")
print("\n".join(msgs[-12:]))
PYEOF
)
          fi
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
