#!/usr/bin/env python3
"""
session-init.py — Claude Code SessionStart hook

Runs automatically at every session boot. Does three things:
  1. Names the session (Haiku API → logical adjective-noun; fallback: wordlist hash)
  2. Color-codes the session (first unused color among live sessions; fallback: silver)
  3. Surfaces context reminders (handoff next-action, environment activation)

Requirements: Claude Code v2.1.152+, Python 3
Optional:     ANTHROPIC_API_KEY for Haiku-generated names
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

COLORS = [
    "blue", "coral", "crimson", "cyan", "gold", "green", "indigo", "ivory",
    "lavender", "lime", "magenta", "maroon", "mint", "navy", "olive", "orange",
    "pink", "purple", "rose", "teal", "violet", "yellow",
]
FALLBACK_COLOR = "silver"

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
# Color
# ---------------------------------------------------------------------------

def get_used_colors():
    sessions_dir = os.path.expanduser("~/.claude/sessions")
    used = set()
    if not os.path.isdir(sessions_dir):
        return used
    for fname in os.listdir(sessions_dir):
        if not fname.endswith(".json"):
            continue
        try:
            pid = int(fname.replace(".json", ""))
            os.kill(pid, 0)
        except (ValueError, ProcessLookupError, PermissionError):
            continue
        try:
            with open(os.path.join(sessions_dir, fname)) as f:
                data = json.load(f)
            color = data.get("color")
            if color:
                used.add(color)
        except (json.JSONDecodeError, IOError):
            continue
    return used

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

def main():
    session_id = os.environ.get("CLAUDE_SESSION_ID", "")
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())
    api_key = os.environ.get("ANTHROPIC_API_KEY", "")

    session_path, session_data = find_session_file(session_id)
    if session_data is None:
        session_data = {}

    # --- NAMING ---
    name = None
    if not session_data.get("name"):
        if api_key:
            name = generate_name_via_api(project_dir, api_key)
        if not name:
            name = generate_name_via_wordlist(project_dir)

        # Official hook output mechanism (v2.1.152+)
        print(json.dumps({"sessionTitle": name}))

        # Belt-and-suspenders: also write to session JSON directly
        if session_path:
            try:
                with open(session_path) as f:
                    current = json.load(f)
                if not current.get("name"):
                    current["name"] = name
                    write_session_file(session_path, current)
                    session_data = current
            except (json.JSONDecodeError, IOError):
                pass

    # --- COLORING ---
    if session_path and not session_data.get("color"):
        used_colors = get_used_colors()
        color = FALLBACK_COLOR
        for c in COLORS:
            if c not in used_colors:
                color = c
                break
        try:
            with open(session_path) as f:
                current = json.load(f)
            if not current.get("color"):
                current["color"] = color
                write_session_file(session_path, current)
        except (json.JSONDecodeError, IOError):
            pass

    # --- REMINDERS (printed to stderr — visible in terminal at startup) ---
    handoff = get_handoff_summary(project_dir)
    if handoff:
        print(f"[resume] {handoff}", file=sys.stderr)

    env = get_env_reminder(project_dir)
    if env:
        print(f"[env] {env}", file=sys.stderr)


if __name__ == "__main__":
    main()
