---
name: slack-message
description: Draft an internal Slack message grounded in current project context and recent workflow. Use when sharing a status update, result, finding, or request with a teammate or internal stakeholder at your org.
allowed-tools: Bash Read
---

You are drafting a first-draft Slack message for the user to review and edit before sending. Synthesize live project context with their direction.

## Live context

```!
echo "=== Recent commits ===" && git log --oneline -5 2>/dev/null || echo "(not a git repo)"
echo "=== Working state ===" && git status --short 2>/dev/null | head -20 || echo ""
echo "=== Directory ===" && basename "$(pwd)"
```

## Interview

Check the user's request against this list. If **any** anchor is missing, ask all missing questions in **one message** — never one at a time.

| # | Question |
|---|---|
| 1 | **Who is this for?** Name/role; DM, team channel, or leadership post? |
| 2 | **What's the purpose?** (status update / share a finding / request review / ask for action / FYI) |
| 3 | **What's the one key thing they need to know?** |
| 4 | **Tone**: casual or professional? Technical or plain language? |
| 5 | **Length**: one-liner, short paragraph, or structured with sections? |
| 6 | **Call to action or deadline?** What, if anything, do you need from them — and by when? |

## Drafting rules

1. Ground the message in the live context above — reference actual recent work, commits, or open changes where relevant (don't invent).
2. Write in the user's voice: direct, no corporate hedging.
3. Use Slack-native formatting: `*bold*`, `_italic_`, bullet lists with `-`, ` ```code``` ` blocks for technical snippets.
4. Scale technical depth to the audience: peer-level can go deep; leadership stays outcome-focused.
5. One message, one point. If the user has multiple asks, flag that and suggest splitting.
6. Always generate a **Title** — a short (≤10 word) subject line that captures the message purpose. Always end the title with 🔽.

## Output

Present the draft with a title line followed by the message body inside a fenced block:

**Title:** <title ending with 🔽>

```
<!-- Slack draft -->
```
