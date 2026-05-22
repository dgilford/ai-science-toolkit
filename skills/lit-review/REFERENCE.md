# lit-review: Mode-Specific Guidance

## `frame` — Framing and refining the research question

**Prioritize:** Reviews, foundational papers, unresolved debates, competing hypotheses.

**Report:**
- *Why* gaps exist: data limitations, methodological barriers, lack of observations
- Competing explanatory frameworks if they exist
- **Novelty check**: truly novel, incremental extension, replication, or already done

---

## `methods` — Designing methods and analytical strategy

**Prioritize:** Methods papers, comparative studies, benchmark datasets, software implementations.

**Report:**
- **What the last 3–5 papers on this topic actually used** — de facto practice over theoretical optimality
- **Known failure modes** per method — where each approach breaks down
- Available code or published implementations worth noting

---

## `interpret` — Interpreting results physically and contextually

**Prioritize:** Results papers, prior quantitative estimates, sensitivity analyses, detection studies.

**Report:**
- **Prior quantitative estimates** — surface comparable estimates with uncertainty ranges and methods
- **Observational vs. model agreement** — does consensus come from models, observations, or both? Flag disagreement

---

## `landscape` — Establishing credibility and field awareness

**Prioritize:** High-impact papers, review articles, prior claims, citation networks.

**Report:**
- **Key groups and labs** — identify who is most active: names, institutions, recent output
- **Where the field is heading** — what the most-cited recent papers signal
- Claim-by-claim support: strongest citation per major claim; flag weakly supported ones
- Counterarguments the community is likely to raise

---

## `synthesize` — Future directions and synthesis opportunities

**Prioritize:** Debates, underused datasets, emerging frameworks, methodological tensions.

**Report:**
- **Contradiction map**: where papers disagree and whether it's about methods, data, or physical mechanisms
- Datasets that exist but haven't been applied to this question
- Meta-analysis, intercomparison, or replication opportunities

---

## REFERENCES.md append template

Location: project root `REFERENCES.md`. Always append — never overwrite. Each entry is a dated block.

```markdown
---
## [YYYY-MM-DD] — [Topic]
**Mode**: [frame / methods / interpret / landscape / synthesize]
**Query**: [what was searched]

### Key papers
- [Authors (Year). Title. *Journal/Venue*. [preprint]] — [one-line annotation]

### Gaps and open questions
- [what the search did not find or resolve]
---
```

---

## Confidence calibration

- **Established** — broad consensus, replicated across methods and groups
- **Debated** — contested; multiple defensible positions exist
- **Emerging** — recent, not yet replicated or broadly accepted
- **Speculative** — limited evidence; flag explicitly
