#!/usr/bin/env bash
# ShellCheck every tracked shell script.
#
# Single source of truth for the shell lint: both .github/workflows/lint.yml and
# scripts/sync.sh call this, so CI and the local push gate can't disagree about
# what gets checked. It previously lived as a hardcoded list in the workflow,
# which had already silently drifted — the step was named "all tracked shell
# scripts" while omitting settings/statusline-command.sh.
#
# Targets are discovered with `git ls-files`, so a new tracked script is covered
# the moment it's committed. Untracked and gitignored trees (skills/tab-setup/,
# tab-setup/) are deliberately out of scope: they're deployed copies or a
# separate upstream's code, linted in their own repo.
#
# Usage: bash scripts/lint-shell.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# -S warning: fail on real defects, not style notes.
SEVERITY="warning"

# Prefer PATH, then the pip-installed shellcheck-py binary. It lives in
# ~/.local/bin, which isn't always on PATH — the local gate silently skipped the
# shell lint for exactly that reason while CI enforced it, so an SC2115 landed on
# main. Resolve it explicitly rather than trusting PATH.
if command -v shellcheck >/dev/null 2>&1; then
  SHELLCHECK="$(command -v shellcheck)"
elif [ -x "$HOME/.local/bin/shellcheck" ]; then
  SHELLCHECK="$HOME/.local/bin/shellcheck"
elif [ "${REQUIRE_SHELLCHECK:-0}" = "1" ]; then
  # CI sets this. A missing linter must fail the build, never pass quietly —
  # silently-skipped checks are what let the defect this script exists for reach
  # main in the first place.
  echo "  ✗ shellcheck not found and REQUIRE_SHELLCHECK=1 — refusing to skip" >&2
  exit 1
else
  echo "  ! shellcheck not found (PATH or ~/.local/bin) — shell scripts NOT linted" >&2
  echo "    Install: python3 -m pip install --user shellcheck-py" >&2
  exit 0
fi

# shellcheck disable=SC2207  # paths here have no spaces; keeps bash-3.2 compat
TARGETS=($(git ls-files '*.sh'))

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "  ! no tracked *.sh found — shell scripts NOT linted" >&2
  exit 0
fi

if "$SHELLCHECK" -S "$SEVERITY" "${TARGETS[@]}"; then
  echo "  ✓ shellcheck passed (${#TARGETS[@]} tracked scripts, -S $SEVERITY)"
else
  echo "  ✗ shellcheck found defects in tracked shell scripts (-S $SEVERITY)" >&2
  exit 1
fi
