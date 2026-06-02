# Colorblind-Friendly Figure Practices

Sources: Okabe & Ito (2008); Wong (2011, *Nature Methods* 8:441); ColorBrewer; CTAO Colour Blind Friendly Practices v2 (2025)

~8% of males and ~0.5% of females have some form of color vision deficiency (CVD). Deuteranopia/anomaly (red-green) is the most common (~6% of males); protanopia (~2%); tritanopia (blue-yellow, rare).

---

## Colormaps to flag

| Colormap | Problem |
|---|---|
| jet / rainbow / HSV | Encodes data with hue only — fails all CVD types; also introduces false boundaries |
| Red–Green diverging | Fails deuteranopia and protanopia (majority of CVD) |
| Red alone for "bad" / Green alone for "good" | Invisible distinction to protanopes and deuteranopes |
| Brown–Green pairs | Confused under deuteranopia |
| Blue–Purple pairs | Hard to distinguish under tritanopia |

## Safe alternatives

**Sequential:** viridis, plasma, magma, inferno, cividis (perceptually uniform; cividis optimized for deuteranopia); cmocean: `thermal`, `haline`, `deep`, `matter`, `ice`, `amp`

**Diverging:** RdBu, coolwarm, bwr are acceptable; avoid RdGn. Blue–orange or purple–orange diverging maps are safest.

**Discrete (≤8 categories):** Okabe-Ito / Wong palette — designed for CVD safety:

| Name | Hex |
|---|---|
| Orange | `#E69F00` |
| Sky blue | `#56B4E9` |
| Bluish green | `#009E73` |
| Yellow | `#F0E442` |
| Blue | `#0072B2` |
| Vermillion | `#D55E00` |
| Reddish purple | `#CC79A7` |
| Black | `#000000` |

---

## Rules

1. **Never encode with color alone.** Use shape, line style, or pattern as a redundant channel.
2. **Check luminance contrast**, not just hue — colors that differ in hue but match in brightness are indistinguishable in grayscale and under CVD.
3. **Test before publishing.** Tools: [Coblis](https://www.color-blindness.com/coblis-color-blindness-simulator/), Color Oracle (desktop), Sim Daltonism (macOS/iOS).

---

## Climate Central palette notes

| Color | Hex | CVD status |
|---|---|---|
| Primary Blue | `#074F92` | Safe |
| Bright Blue | `#0083B7` | Safe |
| Deep Navy | `#022749` | Safe |
| Coral | `#FF6046` | **Flag** if paired with green or used as sole differentiator |
| Orange | `#FF9450` | Generally safe; verify with protanopia sim |
| Yellow | `#FFDE6B` | Safe hue; low luminance contrast on white — check contrast ratio |
| Medium Blue | `#7BB0DD` | Safe |
| Light Blue | `#B9D6EE` | Safe; may be confused with `#7BB0DD` at small sizes |
| Gray | `#B0B0AF` | Safe |
