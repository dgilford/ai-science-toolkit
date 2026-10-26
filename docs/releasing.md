# Releasing

Release and citation procedure. `CLAUDE.md` keeps only the pointer.

**Four version slots** must be bumped together, and nothing lints them against each other or against the git tag: `CITATION.cff` (plus `date-released`), `.zenodo.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`. **`.zenodo.json` is the easy one to miss** — it isn't referenced from the plugin docs and never surfaces in a `/plugin` workflow. Grep for the outgoing version across the repo before tagging.

Tagged releases are archived to Zenodo (the repo↔Zenodo webhook is enabled), which mints a DOI. Non-obvious convention for the two DOI slots — **do not swap them on future releases:**
- **`CITATION.cff` `doi:` → the version DOI** (pins the specific release; bump it each release alongside `version`/`date-released`). It must track `version:` — a concept DOI here would contradict the version number sitting next to it, and FORCE11 software-citation practice is to cite the specific version used.
- **`CITATION.cff` `identifiers:` → both DOIs**, each with a `description` (the CFF-spec pattern), so the never-stale concept DOI is still discoverable from the citation file. Update the versioned entry's value *and* its description each release.
- **`README.md` badge → the concept (all-versions) DOI** (always resolves to the latest release; leave it unchanged across releases).

**Chicken-and-egg:** Zenodo mints the version DOI *from* the published release, so the DOI naming a release can never be inside that release's own archive — it always lands one commit after the tag. Don't try to fix this by pre-tagging; just paste it in on `main` afterward.

**Look the new DOI up, never guess it** — version record ids are not sequential with the concept id (v1.0.0 was `…21461069`, one past the concept `…21461068`; v1.1.0 was `…21682976`, nowhere near). The concept record id redirects to the latest version, so one call resolves it and confirms the webhook actually fired:

```bash
curl -sL "https://zenodo.org/api/records/<CONCEPT_ID>" | python3 -c \
  "import json,sys; d=json.load(sys.stdin); print(d['doi'], d['metadata']['version'])"
```

**The stale-DOI trap is three-legged**, and the third leg rots silently: the top-level `doi:`, the versioned `identifiers` value, *and* that entry's `description` (which names the version in prose, so YAML validation can't catch it). After editing, assert the old DOI is gone rather than eyeballing it: `grep -q '<OLD_VERSION_DOI>' CITATION.cff && echo STALE`.

Zenodo only captures releases published *after* the webhook was enabled, and only a real GitHub **Release** (not a bare `git tag`) fires it. Cutting a release: publish a GitHub Release for tag `vX.Y.Z` from `main` (e.g. `gh release create vX.Y.Z --target main`, or the web UI).
