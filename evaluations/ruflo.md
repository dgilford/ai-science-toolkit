# Ruflo Evaluation

Branch: `eval/ruflo-harness`
Started: 2026-06-29

> **Reproducibility caveat:** every command below ran `npx -y ruflo@latest` and the resolved
> version was not recorded, so the scores and behavioral conclusions are pinned to an unknown
> version around 2026-06-29. Future evaluations should record `npx ruflo --version` alongside
> results; the sandboxing conclusion in §4 in particular generalizes from a single run of one
> subcommand.

Goal: test Ruflo features in order of likely fit for this repo without letting
generated state become part of the source-of-truth tool repo.

## Guardrails

- Do not run `npx ruflo init` in this repo until the read-only/sandboxed tests
  justify a fuller trial.
- Keep generated Ruflo state out of git. `.gitignore` excludes `.claude/`,
  `.claude-flow/`, `.metaharness/`, `.swarm/`, and `ruvector.db`.
- The `window-warmup-heartbeat` branch is active in another worktree at
  `/private/tmp/ww-heartbeat`; do not touch it from this branch.

## 1. MetaHarness

Commands:

```sh
npx -y ruflo@latest doctor --component metaharness
npx -y ruflo@latest metaharness score --path . --format json
npx -y ruflo@latest metaharness genome --path . --format json
npx -y ruflo@latest metaharness mcp-scan --path . --fail-on high --format json
npx -y ruflo@latest metaharness threat-model --path . --fail-on high --format json
```

Results:

- Doctor loaded the ONNX embedder and reported MetaHarness installed, but with an
  unparseable version string.
- Score classified this repo as a `devops-harness` with `harnessFit: 56`,
  `compileConfidence: 22`, `taskCoverage: 65`, `toolSafety: 100`,
  `memoryUsefulness: 31`, and `scaffoldReady: false`.
- Genome reported `repo_type: unknown_ci`, `risk_score: 0.56`,
  `mcp_surface: local_default_deny`, `test_confidence: 0.3`, and
  `publish_readiness: 0.25`.
- MCP scan and threat model were clean, but mostly because this repo has no
  project-local MCP surface to scan.

Assessment:

- Useful as a rough external scorecard, especially for tool-safety and MCP
  exposure checks.
- Current scoring under-values this repo because it is mostly skills, agents,
  docs, and shell scripts rather than a conventional compiled package.
- Best next use would be a periodic read-only audit after adding any project-local
  MCP or hook surface.

## 2. Diff Risk / Jujutsu

Command:

```sh
npx -y ruflo@latest analyze diff 24f94e68dffb51a681ca1e16a4f86e6971ef3bf8..c6382bac822bd221197b98b26367237bdc87cb4a \
  --risk --classify --reviewers --format json --verbose
```

Results:

- Symbolic range `HEAD~1..HEAD` was rejected as `Invalid git ref: suspicious
  pattern`.
- Explicit SHA range worked.
- For the merged window-warmup PR, Ruflo reported 6 files changed, 171 additions,
  28 deletions, overall `low` risk, score `0`, and recommended reviewer
  `developer`.
- Classification was `unknown` with confidence `0.6`.

Assessment:

- Useful as a fast structured diff summary.
- Weak as a risk gate for this repo: launchd plist, shell scripts, and GitHub
  Actions workflow changes all scored zero risk.
- If adopted, use only as a pre-review triage aid. Keep normal review and
  verification as the authority.

## 3. Workflows

Commands:

```sh
npx -y ruflo@latest workflow --help
npx -y ruflo@latest workflow validate --help
```

Results:

- Bare CLI exposes `run`, `validate`, `list`, `status`, `stop`, and `template`.
- The richer workflow value described by Ruflo depends on installing the Claude
  plugin/MCP/full loop.

Assessment:

- Likely useful for a structured reviewer-panel workflow, but not worth testing
  further until deciding whether to allow a project-local `.claude/workflows/`
  or Ruflo plugin install.

## 4. Memory

Command:

```sh
npx -y ruflo@latest memory init --path /private/tmp/ruflo-memory-sandbox/memory.db --force --verbose
```

Results:

- Ruflo initialized the requested `/private/tmp` memory DB and passed its
  verification tests.
- Despite `--path /private/tmp/...`, it also wrote repo-local generated state:
  `.claude/memory.db`, `.claude/settings.local.json`, and `ruvector.db`.
- Those generated files were removed after the test.

Assessment:

- The memory layer is potentially relevant to the repo's handoff/resume pattern.
- The current CLI is not cleanly sandboxed by `--path`; it mutates the project
  unless additional isolation is used.
- Do not enable Ruflo memory in this repo without a dedicated test worktree,
  explicit ignore rules, and a cleanup procedure.
