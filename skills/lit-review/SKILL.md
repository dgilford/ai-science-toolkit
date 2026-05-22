---
name: lit-review
description: Search and synthesize scientific literature from Zotero, arxiv, bioRxiv, Google Scholar, and Consensus. Use when framing a research question, designing methods, interpreting results, mapping the field landscape, or identifying future directions.
allowed-tools: mcp__zotero__zotero_search_items mcp__zotero__zotero_item_metadata mcp__zotero__zotero_item_fulltext mcp__arxiv__search_papers mcp__arxiv__semantic_search mcp__arxiv__get_abstract mcp__google-scholar__search_google_scholar_key_words mcp__google-scholar__search_google_scholar_advanced mcp__claude_ai_bioRxiv__search_preprints mcp__claude_ai_Consensus__authenticate mcp__claude_ai_Consensus__complete_authentication Write Edit
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
- **Add to Zotero?** — list papers not already in the library, then ask.
