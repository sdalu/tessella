# Unaligned markdown table fixture

A pipe table whose pipes do not line up in the source. The renderer
does not care, so neither does the anchor check; the figure below it
is still checked.

| Mode | Bandwidth | Range |
| --- | --- | --- |
| LR | 499.2 MHz | 200 m |
| HPRF | 499.2 MHz | 80 m |
| Custom profile | 1331.2 MHz | 40 m |

```text
┌──────────┐
│ Antenna  │
│ (patch)  │
│ 2.4 GHz  │
└──────────┘
```
