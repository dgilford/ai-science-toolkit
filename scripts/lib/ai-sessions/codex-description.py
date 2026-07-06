#!/usr/bin/env python3
"""Extract a one-line description for a Codex CLI session.

Usage: codex-description.py <session_id>

Prefers ~/.codex/session_index.jsonl's thread_name (skipping placeholder
names like "<bash ...>" / "<local ...>"); falls back to the first
user_message event in the session's own transcript file.
"""
import sys, json, os, glob

def describe(sid):
    idx = os.path.expanduser("~/.codex/session_index.jsonl")
    try:
        with open(idx) as f:
            for line in f:
                d = json.loads(line)
                if d.get("id") == sid:
                    name = d.get("thread_name", "")
                    if name and not name.startswith("<bash") and not name.startswith("<local"):
                        return name[:120]
    except Exception:
        pass

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
                        return msg[:120].replace("\n", " ")
        except Exception:
            pass
    return None

if __name__ == "__main__":
    out = describe(sys.argv[1])
    if out:
        print(out)
