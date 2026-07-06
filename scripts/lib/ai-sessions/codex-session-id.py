#!/usr/bin/env python3
"""Find the newest Codex CLI session ID whose recorded cwd matches the given one.

Usage: codex-session-id.py <cwd>

Searches ~/.codex/sessions/**/*.jsonl (newest first, by filename sort) for a
session whose first line's payload.cwd matches.
"""
import sys, json, os, glob

def find_session_id(cwd):
    base = os.path.expanduser("~/.codex/sessions")
    for f in sorted(glob.glob(f"{base}/**/*.jsonl", recursive=True), reverse=True):
        try:
            d = json.loads(open(f).readline())
            if d.get("payload", {}).get("cwd") == cwd:
                return d["payload"]["id"]
        except Exception:
            pass
    return None

if __name__ == "__main__":
    sid = find_session_id(sys.argv[1])
    if sid:
        print(sid)
