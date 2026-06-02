---
name: lit-review
description: Search and synthesize scientific literature from Zotero, arxiv, bioRxiv, Google Scholar, and Consensus. Use when framing a research question, designing methods, interpreting results, mapping the field landscape, or identifying future directions.
allowed-tools: mcp__zotero__zotero_search_items mcp__zotero__zotero_item_metadata mcp__zotero__zotero_item_fulltext mcp__arxiv__search_papers mcp__arxiv__semantic_search mcp__arxiv__get_abstract mcp__google-scholar__search_google_scholar_key_words mcp__google-scholar__search_google_scholar_advanced mcp__claude_ai_bioRxiv__search_preprints mcp__claude_ai_Consensus__authenticate mcp__claude_ai_Consensus__complete_authentication Bash Write Edit
---

Conduct a literature search and deliver a structured scientific briefing. See [REFERENCE.md](REFERENCE.md) for mode-specific guidance.

## On invocation, ask the user

1. **Topic** — what are we searching for?
2. **Mode** — `frame` / `methods` / `interpret` / `landscape` / `synthesize`
3. **Starting point** (optional) — any known papers, authors, or search terms to seed from?

## Search order

1. **Zotero** — existing library first; note what's already there
2. **Consensus** — synthesized search for landscape and key claims
3. **Google Scholar** — seminal works, citation counts, author networks
4. **arxiv / bioRxiv** — recent and unpublished work

Stop adding sources once coverage is sufficient for the mode.

## Output structure

**1. High-level summary** — 1–2 paragraphs: what the field looks like, what is settled, what is contested. Tag findings as *established / debated / emerging* throughout.

**2. Topical review** — key ideas, findings, and debates organized by theme. Apply mode-specific guidance from REFERENCE.md. Distinguish what is well-established, actively debated, and absent.

**3. Papers** — for each paper:
- Full citation (authors, year, title, journal/venue)
- Peer-reviewed or preprint — flag explicitly
- Key contribution in 1–2 sentences
- Relevance to the current topic and mode

**4. Offers** — always prompt:

- **Save to `REFERENCES.md`?** — check if it exists and show existing entries first. Append using the template in REFERENCE.md. Never overwrite.
- **Add to Zotero?** — list papers not already in the library, then ask. If yes, execute the steps below.

## Adding papers to Zotero

**User ID:** `12937876`  
**Inbox collection:** `11 Inbox / To Sort`  
**API key env var:** `$ZOTERO_API_KEY`

**Step 1 — resolve the collection key:**
```bash
curl -s "https://api.zotero.org/users/12937876/collections?limit=100" \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  | python3 -c "
import sys, json
cols = json.load(sys.stdin)
for c in cols:
    if c['data']['name'] == '11 Inbox / To Sort':
        print(c['key'])
"
```

**Step 2 — POST items.** Build a JSON array; one object per paper. Use `itemType` `journalArticle` for peer-reviewed, `preprint` for arxiv/bioRxiv. Include `collections: [\"<KEY>\"]` from Step 1.

Minimum required fields per item:
- `itemType`, `title`, `date`
- `creators`: `[{"creatorType": "author", "firstName": "...", "lastName": "..."}]`
- `DOI` or `url` (include both when available)
- `collections`: `["<inbox-key>"]`
- `tags`: `[{"tag": "lit-review"}]`

```bash
curl -s -X POST "https://api.zotero.org/users/12937876/items" \
  -H "Zotero-API-Key: $ZOTERO_API_KEY" \
  -H "Content-Type: application/json" \
  -d '<JSON array>'
```

**Step 3 — report results.** Parse the response: list titles that succeeded (HTTP 200 `success` key) and any that failed (`failed` key). A paper already in the library does not need to be re-added.
