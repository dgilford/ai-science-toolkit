#!/usr/bin/env python3
"""
session-init.py — Claude Code SessionStart hook

Runs automatically at every session boot. Does two things:
  1. Names the session (Haiku API → logical adjective-noun; fallback: wordlist hash)
  2. Surfaces context reminders (handoff next-action, environment activation)

Color is handled by /tab-setup (user-invoked skill) — not this hook.

Requirements: Claude Code v2.1.152+, Python 3
Optional:     ANTHROPIC_API_KEY for Haiku-generated names (add to env block in
              ~/.claude/settings.json so the hook inherits it)
Install:      bash scripts/sync.sh push  (from ai-tools repo)

Machine-level env default: ~/.claude/session-init-config.json
  { "default_env": "pixi shell" }
"""

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Color sequence + RGB values — kept in sync with tab-setup/scripts/setup.sh
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

# Seconds to wait inside the AppleScript before injecting /color + /rename.
# Must be long enough for Claude to finish rendering its first prompt after
# the hook exits — 8s is conservative; tune down if startup feels slow.
COLOR_INJECT_DELAY = 8

ADJECTIVES = [
    "amber", "arctic", "blazing", "cobalt", "dappled", "drifting", "ember",
    "emerald", "feral", "gilded", "glacial", "glowing", "hollow", "indigo",
    "jade", "liminal", "lunar", "mellow", "misty", "mossy", "nested", "oblique",
    "onyx", "orbital", "pale", "phantom", "radiant", "rugged", "serene", "shaded",
    "silent", "sinuous", "solar", "spectral", "spiral", "stellar", "tidal",
    "translucent", "twilight", "verdant",
]

NOUNS = [
    "anchor", "apex", "basin", "beacon", "canopy", "cascade", "circuit", "cliff",
    "conduit", "crater", "delta", "drift", "ember", "fjord", "fractal", "glacier",
    "glyph", "grove", "harbor", "horizon", "inlet", "lattice", "ledge", "lotus",
    "mesa", "mirror", "nexus", "orbit", "outcrop", "peak", "prism", "pulse",
    "ridge", "reef", "signal", "slate", "summit", "tide", "vale", "veil",
]

# ---------------------------------------------------------------------------
# Session file helpers
# ---------------------------------------------------------------------------

def find_session_file(session_id, retries=5, delay=0.1):
    sessions_dir = os.path.expanduser("~/.claude/sessions")
    if not os.path.isdir(sessions_dir):
        return None, None
    for _ in range(retries):
        for fname in os.listdir(sessions_dir):
            if not fname.endswith(".json"):
                continue
            fpath = os.path.join(sessions_dir, fname)
            try:
                with open(fpath) as f:
                    data = json.load(f)
                if data.get("sessionId") == session_id:
                    return fpath, data
            except (json.JSONDecodeError, IOError):
                continue
        time.sleep(delay)
    return None, None


def write_session_file(path, data, retries=3, delay=0.05):
    for attempt in range(retries):
        try:
            tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(path))
            try:
                with os.fdopen(tmp_fd, "w") as f:
                    json.dump(data, f)
                os.replace(tmp_path, path)
                return
            except Exception:
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass
                raise
        except IOError:
            if attempt < retries - 1:
                time.sleep(delay)

# ---------------------------------------------------------------------------
# Auto-color helpers
# ---------------------------------------------------------------------------

def get_current_tty():
    try:
        result = subprocess.run(["tty"], capture_output=True, text=True, timeout=2)
        tty = result.stdout.strip()
        if result.returncode == 0 and tty and tty != "not a tty":
            return tty
    except Exception:
        pass
    return None


def find_session_by_tty(tty_dev, retries=10, delay=0.3):
    """Return (claude_pid, session_id) by matching tty_dev against live session files."""
    sessions_dir = os.path.expanduser("~/.claude/sessions")
    tty_short = tty_dev.replace("/dev/", "")
    if not os.path.isdir(sessions_dir):
        return None, None
    for _ in range(retries):
        for fname in os.listdir(sessions_dir):
            if not fname.endswith(".json"):
                continue
            fpath = os.path.join(sessions_dir, fname)
            try:
                with open(fpath) as f:
                    data = json.load(f)
                pid = data.get("pid")
                if not pid:
                    continue
                os.kill(pid, 0)
                result = subprocess.run(
                    ["ps", "-o", "tty=", "-p", str(pid)],
                    capture_output=True, text=True, timeout=2,
                )
                if result.returncode == 0 and result.stdout.strip() == tty_short:
                    return pid, data.get("sessionId", "")
            except (json.JSONDecodeError, IOError, OSError, ProcessLookupError):
                continue
        time.sleep(delay)
    return None, None


def auto_color(session_id, claude_pid, tty_dev, project_dir):
    """Pick the next available color, write iTerm2 escape codes, and schedule
    /color + /rename injection via a background AppleScript."""
    tracking_file = os.path.expanduser("~/.claude/tab-colors.json")
    watcher_sh = os.path.expanduser("~/.claude/skills/tab-setup/scripts/watcher.sh")
    tab_name = os.path.basename(project_dir.rstrip("/"))

    if not os.path.exists(tracking_file):
        with open(tracking_file, "w") as f:
            json.dump({}, f)
    try:
        with open(tracking_file) as f:
            tracking = json.load(f)
    except Exception:
        tracking = {}

    tracking.pop(session_id, None)
    live, used_colors = {}, set()
    for sid, entry in tracking.items():
        try:
            os.kill(entry.get("pid", 0), 0)
            live[sid] = entry
            used_colors.add(entry.get("color", ""))
        except (OSError, ProcessLookupError):
            pass

    chosen = next((c for c in SEQUENCE if c not in used_colors), SEQUENCE[0])
    r, g, b = COLORS[chosen]

    live[session_id] = {"color": chosen, "pid": claude_pid, "cwd": project_dir, "name": tab_name}
    with open(tracking_file, "w") as f:
        json.dump(live, f, indent=2)

    # Write iTerm2 tab color escape codes immediately to the terminal device
    try:
        with open(tty_dev, "w") as tty_f:
            tty_f.write(f"\033]6;1;bg;red;brightness;{r}\007")
            tty_f.write(f"\033]6;1;bg;green;brightness;{g}\007")
            tty_f.write(f"\033]6;1;bg;blue;brightness;{b}\007")
            tty_f.flush()
    except IOError:
        pass

    # Background AppleScript: inject /color + /rename after Claude's first prompt
    ascript = f"""on run argv
  set ttyDevice to item 1 of argv
  set tabName to item 2 of argv
  set tabColor to item 3 of argv
  delay {COLOR_INJECT_DELAY}
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
"""
    ascript_path = os.path.expanduser("~/.claude/tab-setup-hook.applescript")
    try:
        with open(ascript_path, "w") as f:
            f.write(ascript)
        subprocess.Popen(
            ["nohup", "osascript", ascript_path, tty_dev, tab_name, chosen],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception as e:
        debug_log(f"  auto-color osascript error: {e}")

    # Launch watcher to clean up tracking file when Claude exits
    if os.path.exists(watcher_sh):
        try:
            subprocess.Popen(
                ["bash", watcher_sh, str(claude_pid), session_id],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except Exception:
            pass

    return chosen, tab_name


# ---------------------------------------------------------------------------
# Naming
# ---------------------------------------------------------------------------

def get_project_context(project_dir):
    name = os.path.basename(project_dir.rstrip("/"))
    try:
        result = subprocess.run(
            ["git", "-C", project_dir, "remote", "get-url", "origin"],
            capture_output=True, text=True, timeout=3,
        )
        if result.returncode == 0:
            remote = result.stdout.strip()
            remote_name = re.split(r"[/:]", remote.rstrip("/"))[-1]
            remote_name = re.sub(r"\.git$", "", remote_name)
            if remote_name:
                name = remote_name
    except Exception:
        pass
    return name


def generate_name_via_api(project_dir, api_key):
    project_name = get_project_context(project_dir)
    prompt = (
        f"Generate a memorable 2-word adjective-noun name for a coding session "
        f"in the project '{project_name}'. Make it logically reflect the project's "
        f"purpose or domain. Reply ONLY with the name in lowercase-hyphenated "
        f"format, e.g. 'fiscal-ledger' or 'scholarly-atlas'. No explanation."
    )
    payload = {
        "model": "claude-haiku-4-5-20251001",
        "max_tokens": 20,
        "messages": [{"role": "user", "content": prompt}],
    }
    try:
        result = subprocess.run(
            [
                "curl", "-s", "-f",
                "https://api.anthropic.com/v1/messages",
                "-H", f"x-api-key: {api_key}",
                "-H", "anthropic-version: 2023-06-01",
                "-H", "content-type: application/json",
                "-d", json.dumps(payload),
                "--max-time", "5",
            ],
            capture_output=True, text=True, timeout=8,
        )
        if result.returncode == 0:
            resp = json.loads(result.stdout)
            text = resp["content"][0]["text"].strip().lower()
            if re.match(r"^[a-z]+-[a-z]+$", text):
                return text
    except Exception:
        pass
    return None


def generate_name_via_wordlist(project_dir):
    h = int(hashlib.md5(project_dir.encode()).hexdigest(), 16)
    adj = ADJECTIVES[h % len(ADJECTIVES)]
    noun = NOUNS[(h >> 16) % len(NOUNS)]
    return f"{adj}-{noun}"

# ---------------------------------------------------------------------------
# Reminders
# ---------------------------------------------------------------------------

def get_handoff_summary(project_dir):
    """Return a one-liner from .ai/HANDOFF.md if it exists."""
    handoff_path = os.path.join(project_dir, ".ai", "HANDOFF.md")
    if not os.path.exists(handoff_path):
        return None
    try:
        with open(handoff_path) as f:
            content = f.read()

        objective = None
        obj_match = re.search(r"##\s*Objective\s*\n+(.*?)(?:\n##|\Z)", content, re.DOTALL)
        if obj_match:
            for line in obj_match.group(1).split("\n"):
                line = line.strip()
                if line and not line.startswith("<!--"):
                    objective = line
                    break

        next_action = None
        na_match = re.search(r"##\s*Next actions\s*\n+(.*?)(?:\n##|\Z)", content, re.DOTALL)
        if na_match:
            for line in na_match.group(1).split("\n"):
                line = line.strip()
                if line and not line.startswith("<!--") and re.match(r"^\d+\.", line):
                    next_action = re.sub(r"^\d+\.\s*", "", line)
                    break

        if objective and next_action:
            return f"{objective} → {next_action}"
        elif objective:
            return objective
        elif next_action:
            return next_action
    except IOError:
        pass
    return None


def get_env_reminder(project_dir):
    """
    Env detection priority:
      1. pixi.toml in project dir
      2. environment.yml in project dir
      3. .python-version in project dir
      4. .claude-session in project dir
      5. ~/.claude/session-init-config.json default_env (machine-level fallback)
    """
    # 1. pixi
    if os.path.exists(os.path.join(project_dir, "pixi.toml")):
        return "run: pixi shell"

    # 2. conda environment.yml
    env_yml = os.path.join(project_dir, "environment.yml")
    if os.path.exists(env_yml):
        try:
            with open(env_yml) as f:
                for line in f:
                    m = re.match(r"^name:\s*(.+)", line.strip())
                    if m:
                        env_name = m.group(1).strip()
                        return f"activate: conda {env_name}"
        except IOError:
            pass
        return "activate: conda (see environment.yml)"

    # 3. .python-version
    pv_path = os.path.join(project_dir, ".python-version")
    if os.path.exists(pv_path):
        try:
            with open(pv_path) as f:
                version = f.read().strip()
            if version:
                return f"python {version}"
        except IOError:
            pass

    # 4. .claude-session (explicit project-level override)
    cs_path = os.path.join(project_dir, ".claude-session")
    if os.path.exists(cs_path):
        try:
            with open(cs_path) as f:
                for line in f:
                    line = line.strip()
                    m = re.match(r"^(conda|pixi|env|run):\s*(.+)", line)
                    if m:
                        key, val = m.group(1), m.group(2).strip()
                        if key == "conda":
                            return f"activate: conda {val}"
                        elif key == "pixi":
                            return "run: pixi shell"
                        else:
                            return f"run: {val}"
        except IOError:
            pass

    # 5. Machine-level default
    config_path = os.path.expanduser("~/.claude/session-init-config.json")
    if os.path.exists(config_path):
        try:
            with open(config_path) as f:
                config = json.load(f)
            default_env = config.get("default_env", "").strip()
            if default_env:
                return f"run: {default_env}"
        except (json.JSONDecodeError, IOError):
            pass

    return None

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

LOG_PATH = os.path.expanduser("~/.claude/session-init-debug.log")


def debug_log(msg):
    try:
        with open(LOG_PATH, "a") as f:
            f.write(f"{msg}\n")
    except IOError:
        pass


def main():
    session_id = os.environ.get("CLAUDE_SESSION_ID", "")
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")

    debug_log(f"--- SessionStart hook fired ---")
    debug_log(f"  session_id={session_id!r}")
    debug_log(f"  project_dir={project_dir!r}")
    debug_log(f"  api_key={'(set)' if api_key else '(missing)'}")

    # Quick initial lookup — may miss the file if it hasn't been written yet
    session_path, session_data = find_session_file(session_id)
    if session_data is None:
        session_data = {}
    debug_log(f"  initial session_path={session_path!r}")

    # --- NAMING ---
    # Generate name before re-checking for the session file; the API call
    # (~5-8s) gives the file time to be created, fixing a SessionStart race.
    name = None
    already_named = session_data.get("name")
    if not already_named:
        if api_key:
            name = generate_name_via_api(project_dir, api_key)
            debug_log(f"  api name={name!r}")
        if not name:
            name = generate_name_via_wordlist(project_dir)
            debug_log(f"  wordlist name={name!r}")

        # Official hook output mechanism (v2.1.152+)
        print(json.dumps({"sessionTitle": name}))

        # Re-lookup after naming delay so the session file is likely present now
        if not session_path:
            session_path, session_data = find_session_file(session_id, retries=10, delay=0.2)
            if session_data is None:
                session_data = {}
            debug_log(f"  re-lookup session_path={session_path!r}")

        # Belt-and-suspenders: also write to session JSON directly
        if session_path:
            try:
                with open(session_path) as f:
                    current = json.load(f)
                if not current.get("name"):
                    current["name"] = name
                    write_session_file(session_path, current)
                    session_data = current
                    debug_log(f"  wrote name={name!r} to session file")
                else:
                    debug_log(f"  name already set in file: {current.get('name')!r}")
            except (json.JSONDecodeError, IOError) as e:
                debug_log(f"  name write error: {e}")
        else:
            debug_log("  no session_path — skipping name write")

    # --- AUTO-COLOR ---
    # Find Claude PID by matching the hook's TTY against live session files.
    # The naming section above gives the session file time to be created.
    tty_dev = get_current_tty()
    if tty_dev:
        claude_pid, found_sid = find_session_by_tty(tty_dev)
        if claude_pid:
            active_sid = found_sid or session_id or "unknown"
            chosen, tab_name = auto_color(active_sid, claude_pid, tty_dev, project_dir)
            debug_log(f"  auto-color: {chosen} / {tab_name} (pid={claude_pid})")
        else:
            debug_log(f"  auto-color: session not found via tty {tty_dev!r}")
    else:
        debug_log("  auto-color: no tty")

    # --- REMINDERS (printed to stderr — visible in terminal at startup) ---
    handoff = get_handoff_summary(project_dir)
    if handoff:
        print(f"[resume] {handoff}", file=sys.stderr)

    env = get_env_reminder(project_dir)
    if env:
        print(f"[env] {env}", file=sys.stderr)


if __name__ == "__main__":
    main()
