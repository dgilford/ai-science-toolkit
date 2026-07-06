#!/usr/bin/env python3
"""Extract a one-line description from a Claude Code session transcript.

Usage: claude-description.py <transcript.jsonl>

Prefers the session's own away_summary recap; falls back to the last
real user message (skipping pure tool-result turns and stripping any
XML-ish tags a user's message might contain).
"""
import sys, json, re

def describe(transcript_path):
    recap = ""
    last_user = ""
    for line in open(transcript_path):
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") == "system" and d.get("subtype") == "away_summary":
            c = (d.get("content") or "").strip()
            if c:
                recap = c
        elif d.get("type") == "user":
            c = d.get("message", {}).get("content", "")
            if isinstance(c, list):
                if all(x.get("type") == "tool_result" for x in c):
                    continue
                text = " ".join(x.get("text", "") for x in c if x.get("type") == "text")
            else:
                text = c if isinstance(c, str) else ""
            text = re.sub(r'<[a-zA-Z][a-zA-Z0-9_-]*(?:\s[^>]*)?>.*?</[a-zA-Z][a-zA-Z0-9_-]*>', '', text, flags=re.DOTALL).strip()
            if text:
                last_user = text
    if recap:
        recap = re.sub(r'\s*\(disable recaps in /config\)\s*$', '', recap)
        return recap.replace("\n", " ").strip()
    if last_user:
        return last_user[:120].replace("\n", " ")
    return ""

if __name__ == "__main__":
    out = describe(sys.argv[1])
    if out:
        print(out)
