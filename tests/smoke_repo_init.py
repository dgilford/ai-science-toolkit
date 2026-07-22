#!/usr/bin/env python3
"""Smoke test for the repo-init skill's TEMPLATES.md.

Three layers:

1. Block validity — every fenced toml/yaml/python block must parse after dummy
   placeholder substitution. Guards syntax only: a semantically wrong value in
   valid YAML/TOML passes this layer.
2. Scaffold semantics — materialize the gitignores in a tmp git repo and assert
   the tracked/ignored contract: data ignored by default, READMEs tracked, and
   the documented `!` escape hatch actually works. Encodes the directory-form
   ignore regression found in review (which silently broke the escape hatch).
3. Semantic spot-checks — known-wrong-but-parseable values, e.g. pre-commit
   hook ids that don't exist at the pinned rev (found in review: `ruff-check`
   didn't exist at v0.8.0).

Run: python3 tests/smoke_repo_init.py   (exit 0 = pass)
Called by `scripts/sync.sh lint` and CI.
"""

import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

TEMPLATES = Path(__file__).resolve().parent.parent / "skills" / "repo-init" / "TEMPLATES.md"

DUMMY = {
    "REPO_NAME": "demo-repo",
    "PKG_NAME": "demo_repo",
    "AUTHOR": "A Name",
    "EMAIL": "a@example.org",
    "COPYRIGHT_HOLDER": "A Name",
    "YEAR": "2026",
    "DATE": "2026-01-01",
    "TIMESTAMP": "2026-01-01 00:00",
}

failures = []


def fail(msg):
    failures.append(msg)


def substitute(text):
    for key, val in DUMMY.items():
        text = text.replace("{{%s}}" % key, val)
    # angle-bracket fills are prose slots, not syntax; make them inert
    return re.sub(r"<[a-z][^>\n]*>", "FILLED", text)


def extract_blocks(md):
    """Yield (section, lang, body) for every fenced block, tagged by nearest ## heading."""
    section = "(top)"
    blocks, lang, buf, in_block = [], None, [], False
    for line in md.splitlines():
        if not in_block and line.startswith("## "):
            section = line[3:].strip()
        if line.startswith("```"):
            if in_block:
                blocks.append((section, lang, "\n".join(buf)))
                in_block, lang, buf = False, None, []
            else:
                in_block, lang = True, line[3:].strip() or "text"
        elif in_block:
            buf.append(line)
    return blocks


def check_block_validity(blocks):
    try:
        import tomllib  # py311+
    except ImportError:
        try:
            import tomli as tomllib  # noqa: N813
        except ImportError:
            tomllib = None
            print("  ! no tomllib/tomli — TOML blocks not validated", file=sys.stderr)
    for section, lang, body in blocks:
        body = substitute(body)
        try:
            if lang == "toml" and tomllib is not None:
                tomllib.loads(body)
            elif lang == "yaml":
                import yaml
                yaml.safe_load(body)
            elif lang == "python":
                compile(body, section, "exec")
        except Exception as e:  # noqa: BLE001 - report every parse failure uniformly
            msg = (str(e) or repr(e)).splitlines()[0]
            fail(f"{section}: {lang} block does not parse: {msg}")


def get_section_block(blocks, prefix, lang=None):
    for section, blang, body in blocks:
        if section.startswith(prefix) and (lang is None or blang == lang):
            return body
    fail(f"template section not found: {prefix}")
    return None


def git(repo, *args, check=True):
    # Isolate from user/system git config: a global core.excludesFile or
    # exported GIT_DIR would silently flip check-ignore assertions.
    env = {k: v for k, v in os.environ.items() if k not in ("GIT_DIR", "GIT_WORK_TREE")}
    env["GIT_CONFIG_GLOBAL"] = os.devnull
    env["GIT_CONFIG_SYSTEM"] = os.devnull
    return subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True, text=True, check=check, env=env,
    )


def is_ignored(repo, path):
    return git(repo, "check-ignore", "-q", path, check=False).returncode == 0


def check_scaffold_semantics(blocks):
    core = get_section_block(blocks, "GITIGNORE-CORE")
    research = get_section_block(blocks, "GITIGNORE-RESEARCH")
    package = get_section_block(blocks, "GITIGNORE-PACKAGE")
    if core is None or research is None or package is None:
        return

    with tempfile.TemporaryDirectory() as tmp:
        repo = Path(tmp)
        git(repo, "init", "-q")
        (repo / ".gitignore").write_text(core + "\n" + research + "\n")
        for d in ("data/inputs", "data/outputs", "figures", "docs", ".ai"):
            (repo / d).mkdir(parents=True)

        # the tracked/ignored contract
        expect = {
            "data/README.md": False,        # dir-level README stays tracked
            "figures/README.md": False,     # allowlisted anchor stays tracked
            "data/inputs/raw.nc": True,     # data ignored by default
            "data/outputs/result.csv": True,
            "figures/fig01.pdf": True,
            "loose_global.nc": True,        # *.nc reaches outside data/
            ".ai/HANDOFF.md": True,
        }
        for path, want_ignored in expect.items():
            p = repo / path
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("x")
            got = is_ignored(repo, path)
            if got != want_ignored:
                fail(f"research gitignore: {path} is {'ignored' if got else 'tracked'}, "
                     f"expected {'ignored' if want_ignored else 'tracked'}")

        # the documented escape hatch: a trailing `!` entry must actually re-include
        (repo / "data/inputs/keep.nc").write_text("x")
        with (repo / ".gitignore").open("a") as f:
            f.write("!data/inputs/keep.nc\n")
        if is_ignored(repo, "data/inputs/keep.nc"):
            fail("research gitignore: documented `!data/inputs/keep.nc` escape hatch "
                 "does not re-include the file (directory-form ignore regression)")

        # package-mode variant
        (repo / ".gitignore").write_text(core + "\n" + package + "\n")
        (repo / "src").mkdir(exist_ok=True)
        (repo / "src/mod.py").write_text("x")
        if is_ignored(repo, "src/mod.py"):
            fail("package gitignore: source files are ignored")
        if not is_ignored(repo, "fixture.nc"):
            fail("package gitignore: *.nc not ignored")


def check_semantic_expectations(blocks):
    """Layer 3: known-wrong-but-parseable values that layer 1 cannot see."""
    try:
        import yaml
    except ImportError:
        print("  ! PyYAML absent — semantic spot-checks skipped", file=sys.stderr)
        return
    pre = get_section_block(blocks, "PRECOMMIT", lang="yaml")
    if pre is None:
        return
    try:
        cfg = yaml.safe_load(substitute(pre))
        ids = {h["id"] for repo_cfg in cfg["repos"] for h in repo_cfg["hooks"]}
    except Exception as e:  # noqa: BLE001
        fail(f"PRECOMMIT: cannot inspect hooks: {(str(e) or repr(e)).splitlines()[0]}")
        return
    expected = {"ruff-check", "ruff-format"}
    if ids != expected:
        fail(f"PRECOMMIT: hook ids {sorted(ids)} != {sorted(expected)} — wrong ids error at "
             "first commit; `ruff-check` requires rev >= v0.11.10")


def main():
    md = TEMPLATES.read_text()
    blocks = extract_blocks(md)
    if not blocks:
        fail("no fenced blocks found in TEMPLATES.md")

    # every placeholder used must be declared in the header
    declared = set(re.findall(r"`\{\{(\w+)\}\}`", md.split("---")[0]))
    used = set(re.findall(r"\{\{(\w+)\}\}", md))
    for name in sorted(used - declared):
        fail(f"placeholder {{{{{name}}}}} used but not declared in the TEMPLATES.md header")

    check_block_validity(blocks)
    check_scaffold_semantics(blocks)
    check_semantic_expectations(blocks)

    if failures:
        print("  ✗ repo-init template smoke test failed:", file=sys.stderr)
        for f in failures:
            print(f"      {f}", file=sys.stderr)
        sys.exit(1)
    print(f"  ✓ repo-init template smoke test passed ({len(blocks)} blocks)")


if __name__ == "__main__":
    main()
