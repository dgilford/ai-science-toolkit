# repo-init file templates

Placeholders — substitute before writing: `{{REPO_NAME}}` (directory basename), `{{PKG_NAME}}` (repo name sanitized to a valid Python identifier: lowercase, `-`→`_`, strip any leading non-letter characters — if that empties the name, prefix `pkg_`), `{{AUTHOR}}` / `{{EMAIL}}` (from `git config user.name` / `user.email`), `{{COPYRIGHT_HOLDER}}` (from the intake ownership answer; defaults to `{{AUTHOR}}`), `{{YEAR}}`, `{{DATE}}` (today, ISO), `{{TIMESTAMP}}` (now, `YYYY-MM-DD HH:MM` local).

Angle-bracket placeholders like `<answer>` are filled from intake answers at scaffold time — **quoting the user's verbatim reply, never a paraphrase the user didn't give**. If the intake was skipped, write `(intake skipped)`; if a question wasn't asked, `(not asked — <reason>)`.

---

## GITIGNORE-CORE (both modes)

```
# Python
__pycache__/
*.py[cod]

# Jupyter
.ipynb_checkpoints/

# OS
.DS_Store
Thumbs.db

# Environments & credentials
.env
venv/
*.pem
*.key

# Agentic / session-local
.ai/
logs/
```

## GITIGNORE-RESEARCH (append after core)

```
# Data — all ignored by default, inputs and outputs. Tracking a specific file is a
# deliberate exception: append a `!` entry at the end, e.g. `!data/inputs/keep.nc`
data/inputs/*
data/outputs/*
*.nc
*.zarr/

# Figures — regenerable while the project is active; allowlist finals at submission
# (e.g. `!figures/fig01_name.pdf`)
figures/*
!figures/README.md
```

## GITIGNORE-PACKAGE (append after core)

```
# Build / tooling
dist/
*.egg-info/
.pytest_cache/
.ruff_cache/
.mypy_cache/

# Data — large files stay local by default; tracking one is a deliberate `!` exception
*.nc
*.zarr/
```

---

## CLAUDE-STUB → `CLAUDE.md`

```markdown
# CLAUDE.md

Canonical agent guidance lives in **AGENTS.md** — read that first.
Session state and handoffs: `.ai/HANDOFF.md` (gitignored).
```

## AGENTS → `AGENTS.md`

Adapt the Layout table **and the data-related convention bullets** to the files actually created: drop rows and bullets for dirs the chosen mode doesn't scaffold; package mode adds `src/<pkg>/` and `tests/` rows.

```markdown
# AGENTS.md — {{REPO_NAME}}

Canonical guide for AI agents working in this repository. `CLAUDE.md` redirects here.

## Purpose

<answer from intake Q1>

## Hard rules

- Write only inside this repository.

## Layout

| Path | Role |
|---|---|
| `notebooks/` | Exploration and review; index and roles in `notebooks/README.md` |
| `scripts/` | Canonical compute layer; per-script labels in `scripts/README.md` |
| `data/inputs/` | Source data (gitignored; provenance in `data/README.md`) |
| `data/outputs/` | Derived, regenerable products (gitignored) |
| `figures/` | Rendered figures (gitignored; allowlist finals at submission) |
| `docs/` | Decision log (`DECISIONS.md`), memos, navigation docs |
| `.ai/` | Agent session state: handoffs, worklogs, review reports (gitignored) |

## Conventions

- **Script-first for canonical outputs; notebooks for exploration and review.**
- <!-- If you maintain a shared helper library, name it here so agents import from it instead of re-implementing helpers per-repo. -->
- Record irreversible or hard-to-reverse choices in `docs/DECISIONS.md` as they happen.
- When an input in `data/inputs/` changes (QC fix, upstream version update), prefer replacing
  the file and noting it in `docs/DECISIONS.md`, so downstream outputs aren't silently invalidated.

## Commits

Imperative mood; topical, single-concern commits (docs / scripts / notebooks / data separately).
```

## README-STUB → `README.md`

Drop the `notebooks/README.md` bullet in package mode (no `notebooks/` is scaffolded there).

```markdown
# {{REPO_NAME}}

<one-sentence project description, from intake Q1>

## Start here

- `AGENTS.md` — repo guide and layout table (canonical, also for AI agents)
- `docs/DECISIONS.md` — decision log
- `notebooks/README.md` — notebook index

## Environment

<!-- How to set up: environment manager + key dependencies. -->
```

---

## README-NOTEBOOKS → `notebooks/README.md`

```markdown
# Notebooks

Descriptive filenames; one notebook, one job. Keep the index current.

## Index

| Notebook | Role | Notes |
|---|---|---|
<!-- Roles: Source-of-truth / Review / Exploratory / Environment-dependent -->

Source-of-truth notebooks must rerun cleanly top-to-bottom; exploratory ones may go stale (mark them).
```

## README-SCRIPTS → `scripts/README.md`

```markdown
# Scripts

Canonical compute layer — scripts produce canonical outputs; notebooks review them.

## Index

| Script | Label | Purpose |
|---|---|---|
<!-- Labels: Canonical / Diagnostic / Helper / Legacy -->
```

## README-DATA → `data/README.md`

```markdown
# Data

All data is gitignored by default — `inputs/` (source data) and `outputs/` (derived,
regenerable products). Tracking a specific file is a deliberate exception: append a `!`
entry to `.gitignore`.

Git backs up nothing in this directory. For each input, know how you'd get it back: a
download script in this repo, an archived copy somewhere durable (record where in the
table), or accept that it's lose-able — a provenance row alone does not bring data back.

## Provenance

| File | Source | How to re-obtain | Retrieved | Notes |
|---|---|---|---|---|
```

## README-FIGURES → `figures/README.md`

```markdown
# Figures

Working figures are gitignored (`figures/*`; this README is allowlisted) — treat them as
regenerable *while the project is active*. **Final figures are not:** at submission, allowlist
them explicitly in `.gitignore` (e.g. `!figures/fig01_name.pdf`) and commit them — regeneration
years later depends on data and environment records, not code alone.
```

## DECISIONS → `docs/DECISIONS.md`

```markdown
# Decision log

Record irreversible or hard-to-reverse choices as they happen: what was decided, by whom,
why, and what was rejected. Newest first.
Entry heading format: `## YYYY-MM-DD HH:MM — <decision> (<person>)`.

## {{TIMESTAMP}} — repository initialized ({{AUTHOR}})

Scaffolded with `/repo-init`, mode: <research or package>.
Intake answers — the user's verbatim replies, quoted (a day-zero snapshot; these may drift,
so re-check before relying on them):

- **Purpose / end artifact:** "<user's verbatim answer>"
- **Shape / lifespan:** "<user's verbatim answer>"
- **Audience / visibility:** "<user's verbatim answer>"
- **License / ownership:** "<user's verbatim answer>"
- **Data sources / restrictions / repo dependencies:** "<user's verbatim answer>"
- **Reproducibility bar:** "<user's verbatim answer>"
```

---

## PYPROJECT → `pyproject.toml` (package mode)

Set the `license` value from the intake license answer; **delete the `license` line entirely under `--no-license`**.

```toml
[build-system]
requires = ["hatchling", "hatch-vcs"]
build-backend = "hatchling.build"

[project]
name = "{{PKG_NAME}}"
dynamic = ["version"]
description = ""
readme = "README.md"
license = "MIT"
requires-python = ">=3.11"
authors = [{ name = "{{AUTHOR}}", email = "{{EMAIL}}" }]
dependencies = []

[project.optional-dependencies]
test = ["pytest"]

[tool.hatch.version]
source = "vcs"

[tool.hatch.build.targets.wheel]
packages = ["src/{{PKG_NAME}}"]

[tool.ruff]
line-length = 100

[tool.pytest.ini_options]
testpaths = ["tests"]
```

## TEST-STUB → `tests/test_import.py` (package mode)

```python
def test_import():
    import {{PKG_NAME}}  # noqa: F401
```

## INIT-STUB → `src/{{PKG_NAME}}/__init__.py` (package mode)

```python
"""{{REPO_NAME}}."""
```

## CITATION-CFF → `CITATION.cff` (package mode)

Split `{{AUTHOR}}` into given/family names. Set `license` from the intake answer (omit the field under `--no-license`).

```yaml
cff-version: 1.2.0
message: If you use this software, please cite it as below.
title: "{{REPO_NAME}}"
type: software
authors:
  - family-names: <family>
    given-names: <given>
    email: {{EMAIL}}
license: MIT
version: 0.1.0
date-released: "{{DATE}}"
# On first tagged release with a Zenodo webhook enabled:
#   - put the *version* DOI here (bump it each release, with `version` and `date-released`)
#   - put the *concept* (all-versions) DOI in the README badge (it stays fixed)
```

## PRECOMMIT → `.pre-commit-config.yaml` (package mode)

Run `pre-commit autoupdate` after scaffolding to refresh the rev.

```yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.15.22
    hooks:
      - id: ruff-check
      - id: ruff-format
```

## CI-PYTEST → `.github/workflows/pytest.yaml` (package mode)

```yaml
name: tests
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: pip install -e .[test]
      - run: pytest
```

## LICENSE-MIT → `LICENSE`

Use only when the intake license answer is MIT (the default suggestion). For any other
license, fetch its standard text instead. The copyright line uses `{{COPYRIGHT_HOLDER}}` —
the intake ownership answer (a person or an employer), not automatically the git user.

```
MIT License

Copyright (c) {{YEAR}} {{COPYRIGHT_HOLDER}}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
