#!/usr/bin/env bash
# ai-sessions — show running Claude / Codex CLI sessions with session IDs and resume commands
# Usage: ai-sessions
#
# Install (add to ~/.zshrc or ~/.bashrc):
#   source /path/to/ai-tools/scripts/ai-sessions.sh

ai-sessions() {
  # Locate this file's own directory to find scripts/lib/ai-sessions/*.py, whether
  # sourced under bash (BASH_SOURCE) or zsh (BASH_SOURCE is unset there; %x is the
  # zsh equivalent — https://zsh.sourceforge.io/Doc/Release/Prompt-Expansion.html).
  local self_path
  if [ -n "${ZSH_VERSION:-}" ]; then
    # shellcheck disable=SC2296  # zsh-only prompt expansion, not a bash bad-substitution
    self_path="${(%):-%x}"
  else
    self_path="${BASH_SOURCE[0]}"
  fi
  local lib_dir
  lib_dir="$(cd "$(dirname "$self_path")/lib/ai-sessions" && pwd)"

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
      # Claude Code encodes '/', '.', and '_' all as '-' in projects-dir names
      encoded="-$(echo "$cwd" | sed 's|^/||; s|[/._]|-|g')"
      dir="$HOME/.claude/projects/$encoded"
      # newest transcript in this cwd. The projects dir is keyed by cwd, not pid, so two live
      # sessions in the same cwd can't be told apart — both resolve to the most-recently-written one.
      transcript=$(ls -t "$dir"/*.jsonl 2>/dev/null | head -1)
      session_id=$(basename "$transcript" .jsonl 2>/dev/null)
      [[ -n "$session_id" ]] \
        && resume_cmd="claude --resume $session_id" \
        || resume_cmd="claude -c  # (session ID not found)"

      if [[ -n "$transcript" ]]; then
        # away_summary first (Claude's own "* recap:" block), fall back to last user message
        description=$(python3 "$lib_dir/claude-description.py" "$transcript" 2>/dev/null)
      fi

    elif [[ "$cmd" == "codex" ]]; then
      session_id=$(python3 "$lib_dir/codex-session-id.py" "$cwd" 2>/dev/null)
      [[ -n "$session_id" ]] \
        && resume_cmd="codex resume $session_id" \
        || resume_cmd="codex resume --last  # (session ID not found)"

      # try session_index thread_name first; fall back to first user_message in session file
      description=$(python3 "$lib_dir/codex-description.py" "$session_id" 2>/dev/null)
    fi

    printf "  \033[1m%s\033[0m  pid=%-6s  tty=%-8s  %s\n" "$cmd" "$pid" "$tty" "$started"
    printf "  cwd:    %s\n" "${cwd:-unknown}"
    [[ -n "$description" ]] && printf "  \033[33m\"%s\"\033[0m\n" "$description"
    printf "  \033[2mresume: %s\033[0m\n" "$resume_cmd"
    echo ""
  done <<< "$pids"
}
