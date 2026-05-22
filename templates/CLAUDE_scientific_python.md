# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project summary

<!-- One paragraph: what this project does, what scientific question it addresses, and its relationship to other repos/pipelines. -->

## Quick start

```bash
# Environment
pixi install && pixi shell
# or: conda activate <env>

# Run
python <main_script>.py <args>
```

## Architecture

<!-- High-level: what the main script/module does, how data flows through the codebase, key entry points. Avoid listing every file. -->

| File / Dir | Role |
|---|---|
| `<main>.py` | |
| `<config>.json` | |
| `notebooks/` | |
| `data/` | Local cache (gitignored) |
| `outputs/` | Generated outputs (gitignored) |

## Data

<!-- Datasets used: name, source, version, path or retrieval command. -->

| Dataset | Source | Path / Command |
|---|---|---|
| | | |

## Variable conventions

<!-- Non-obvious naming conventions, unit assumptions, coordinate names. -->

- **Baseline / reference period**: <!-- e.g. 1850–1900 pre-industrial -->
- **Counterfactual definition**: <!-- e.g. world without anthropogenic forcing -->
- **Key variables**: <!-- table or list of non-obvious names -->

## Known issues and warn patterns

<!-- Recurring soft-warns, known data quality issues, expected edge cases. Prevent false alarms on the next session. -->

## Key design decisions

<!-- Non-obvious choices: what was decided, why, what was rejected. -->

## Relationship to other repos

<!-- What this repo imports from or exports to. -->

## Linting

```bash
ruff check . && ruff format .
```
