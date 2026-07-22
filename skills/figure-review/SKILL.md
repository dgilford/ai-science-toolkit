---
name: figure-review
description: 'Audit a scientific figure for publication-readiness: colormaps, uncertainty, axis labels, caption completeness, and claim support. Use this whenever the user shares or references a figure, plot, panel, or colorbar for a paper, report, or brief and wants it checked, reviewed, or made publication-ready — even if they just say "does this figure work?" or "review my plot." Emits a per-criterion report; never silently rewrites plotting code.'
allowed-tools: Bash Read Write
argument-hint: "[--style] [--no-archive]"
catalog:
  order: 110
  summary: 'Audit a scientific figure for publication-readiness: colormaps, uncertainty, axis labels, caption completeness, and claim support; `--style` adds CC house style.'
---

## Colorblind reference (loaded at runtime)

```!
D="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/figure-review}"; D="${D:-$HOME/.claude/skills/figure-review}"; cat "$D/COLORBLIND.md" 2>/dev/null || echo "(colorblind guide not found)"
```

## House style (loaded at runtime)

```!
D="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/skills/figure-review}"; D="${D:-$HOME/.claude/skills/figure-review}"; cat "$D/CC-STYLE.md" 2>/dev/null || echo "(no house style configured — criterion 6 skipped)"
```

## Inputs

Accept any subset of: figure image, plotting code, caption, surrounding text claim. Mark `cant-assess` for any criterion that requires input not provided.

## Criteria

**1. Colormap**
Flag colormaps listed as unsafe in the colorblind reference above (jet, rainbow, red–green). Verify sequential vs diverging choice matches data type. Assess luminance contrast. Warn if color is the sole encoding channel (no redundant shape/line style).

**2. Uncertainty**
Flag if a quantitative claim is made and no uncertainty representation is shown (CI, spread, error bars, ensemble range, shading). If no quantitative claim is present, mark `pass`.

**3. Axes**
Labels and units on all axes. Scale (linear/log) appropriate for the data range. Ticks legible.

**4. Caption**
Self-contained. Defines all symbols, abbreviations, line styles. States n, time period, data source.

**5. Claim support**
The figure shows what the surrounding text asserts. Flag over-reach. Requires the text claim as input; otherwise `cant-assess`.
*Example over-reach: figure shows 2°C warming at one station; text claims "warming is accelerating across the region."*

**6. House style** *(only when `--style` is passed)*
Check colors against the CC palette above, graphic fonts (Effra/Bebas/Work Sans), and visual direction (minimal clutter, white space).

## Report

**[Criterion]**: `pass` / `flag` / `cant-assess` — [detail; if flagged, specific fix]
*Example: **Colormap**: `flag` — Uses jet. Replace with viridis or cmo.thermal.*

## Archive

Unless `--no-archive` was passed: after emitting the report, write it verbatim to `.ai/reviews/<YYYY-MM-DD>-figure-review[-<figure-slug>].md` under the repo root (`mkdir -p .ai/reviews`; suffix `-2`, `-3`… on filename collision). Best-effort — if the cwd isn't a git repo or the write fails, add a one-line note and move on; archiving never blocks or alters the review. If `.ai/` is not gitignored (`git check-ignore -q .ai` exits non-zero), warn and suggest adding `.ai/` to `.gitignore`.

## Does not

- Make aesthetic or branding calls beyond the six criteria.
- Rewrite plotting code unless explicitly asked after the report.
