---
name: disclose-project
description: Interview the user phase by phase to write a short publication-ready project-level AI-use disclosure. For each phase include a spectrum-of-involvement (0–10) table plus a statement covering the project's scope and how Claude was used. Use when a paper, report, or other multi-session project is ready for its AI-use statement.
disable-model-invocation: true
allowed-tools: Bash Read Write Grep Glob
argument-hint: "[project or manuscript path] [--no-ledger]"
catalog:
  order: 83
  summary: 'Project-level companion to `disclose`: interviews you phase by phase (design → data → analysis → figures → literature → writing → review) to build a per-phase spectrum-of-involvement table and a publication-ready AI-use statement, primed with the `disclose` ledger and Claude co-author trailers from git.'
---

You interview the user to disclose how Claude was used across a whole project. **User's answers are the source; evidence below only jogs memory and flags
contradictions.** Same 0–10 scale and seven roles as the `disclose` skill (`/disclose`).

## Evidence

```!
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "(not a git repo — interview only)"; exit 0; }
echo "author: $(git config user.name 2>/dev/null || echo '(unset — ask)')"
if git check-ignore -q "$root/.ai/disclosures.jsonl"; then echo "ledger: enabled"; else echo "ledger: disabled (.ai/ not gitignored)"; fi
echo "HEAD: $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
echo "commits: $(git rev-list --count HEAD 2>/dev/null) total, $(git log -i --grep='Co-Authored-By: Claude' --format=%H 2>/dev/null | wc -l | tr -d ' ') with a Claude co-author trailer"
echo "trailer models:"; git log -i --grep='Co-Authored-By: Claude' --format=%B 2>/dev/null | grep -io 'Co-Authored-By: Claude[^<]*' | sort | uniq -c | sort -rn | head -5
echo "files touched in Claude-trailer commits, by top-level dir:"
git log -i --grep='Co-Authored-By: Claude' --name-only --format= 2>/dev/null | grep . | awk -F/ '{print (NF>1?$1"/":$1)}' | sort | uniq -c | sort -rn | head -12
echo "disclose ledger:"
python3 - "$root/.ai/disclosures.jsonl" <<'PY' 2>/dev/null || echo "  (none)"
import json, sys
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
rows = [r for r in rows if r.get("scope") != "project"]
print(f"  {len(rows)} entries")
for r in rows[-15:]:
    print(f"  {r.get('date')} | {r.get('artifact')} | {', '.join(r.get('roles', []))} | SOI {r.get('user_soi')}")
PY
```

Counts returned are used to prompt questions, never shares: a trailer means Claude touched a
commit, not that it wrote it, and chat-pasted work leaves no trailer.

## Anti-Rationalization (hard gate)

**Ask each phase one at a time, waiting for each answer. Do not write a table or statement
until every phase has an answer (a rating or "n/a").**

| Excuse | Why it doesn't hold |
|---|---|
| "The evidence is strong enough to fill this phase in" | Trailers and the ledger miss chat work, other sessions, and verification. Only the user knows. |
| "Seven individual phases is too many; batch them" | Batching invites a skim. One phase per turn; "n/a" makes empty phases cheap. |
| "Overall SOI is just the average of the phases" | Phases differ in weight for the paper. Ask the user for the final summary score. |

## Interview

Phases, in order:

| # | Phase | Roles to probe |
|---|---|---|
| 1 | Conception & design | Ideation, research/synthesis |
| 2 | Data acquisition & processing | Analysis/code, human intervention |
| 3 | Literature | Research/synthesis |
| 4 | Analysis & derivation | Analysis/code, review |
| 5 | Figures | Analysis/code, review |
| 6 | Writing | Drafting, editing |
| 7 | Internal review | Review/critique |

For each phase, show the evidence that speaks to it (matching dirs, ledger entries),
then ask:

```
Phase <!-- n -->: <!-- name -->
Evidence: <!-- relevant trailer counts / ledger entries, or "none in repo" -->

1. What did Claude do here? (or "n/a")
2. How did you check or change its output?
3. Your SOI for this phase (0–10)?
```

**Don't propose a score** — User input anchors the rating. After the answer, flag a clear
conflict with the evidence in one line (e.g. 40 trailer commits under `analysis/` but
rated 1) and accept the user's resolution.

Last turn: show the filled table and ask for the **overall SOI** score and the **model name(s)
and versions** to cite (suggest the trailer models above).

## Output

```
| Phase | Claude's role | Human verification | SOI |
|---|---|---|---|
| <!-- phase --> | <!-- roles, from the user's answer --> | <!-- how they checked it --> | <!-- n or n/a --> |

AI use disclosure: <!-- Author --> designed and conducted this <!-- project noun -->.
Claude (<!-- model(s), versions -->; Anthropic) was used for <!-- roles by phase, e.g.
"code development in data processing and analysis, and line editing of the manuscript" -->.
<!-- Author --> <!-- verification, e.g. "reviewed and tested all code and edited all text" -->
and takes full responsibility for the content (overall spectrum of involvement: <!-- n -->).
```

Use the user's words for roles and verification; offer tightened wording, don't embellish. Apply the
`disclose` drift check: flag wording that implies more or less involvement than the
ratings. Then **offer** to insert into the relevant manuscript file — default to the end, but ask
where. Insert only on a yes.

## Ledger

Unless `--no-ledger` or the evidence block says disabled, append one line to
`<repo>/.ai/disclosures.jsonl` (`mkdir -p` `.ai/`; never edit `.gitignore`):

```json
{"scope": "project", "date": "YYYY-MM-DD", "project": "<label>", "phases": [{"phase": "<name>", "roles": ["..."], "verification": "<...>", "soi": 3, "user_reply": "<verbatim>"}], "overall_soi": 3, "sha": "<short HEAD>", "statement": "<text>"}
```

`user_reply` quotes each phase answer verbatim. Best-effort: a failed write is
mentioned, never blocks.

## Verification

- [ ] Each of the 7 phases asked one at a time, with an answer recorded before the next
- [ ] No SOI (overall or for individual phases) proposed or assumed by you; conflicts with evidence flagged, user's resolution kept
- [ ] Table and statement use the user's words; drift check run
- [ ] Insertion offered; ledger written with verbatim replies, or skipped and explained
