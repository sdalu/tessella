# tessella documentation

tessella draws text figures on a monospace grid, in Unicode or pure
ASCII: charts, trees, tables, bit-field, timing and sequence
diagrams, and pictures, all of which compose into one figure. Its
output is meant for documents first: no trailing blank, no escape
code unless asked, ASCII from the first byte when asked.

```text
$ ruby datasheet.rb
           CTRL (0x04)

 0                   1
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
| MODE  |      DIV      |  EN   |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

─────────────────────────────────────

     ──┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
sclk   └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─

     ────┐                       ┌───
cs       └───────────────────────┘

     ▒▒▒▒╳       ╳       ╳       ▒▒▒▒
mosi ▒▒▒▒╳──CMD──╳─ADDR──╳─DATA──▒▒▒▒
```

## Guide

1. [Getting started](getting-started.md): install, a first chart, a
   first diagram, the library.
2. [Charts](charts.md): line, scatter, stairs, density, bar,
   histogram, box and stem; input formats, options, canvases, colour,
   ASCII.
3. [Composition](composition.md): blocks; frame, beside, stack,
   indent, caption, shadow, fill.
4. Diagrams: [trees](tree.md), [tables](table.md),
   [bit fields](bitfield.md), [timing diagrams](wave.md),
   [sequence diagrams](seq.md).
5. [Pictures](images.md): images as text.
6. One-liners: [meters](meter.md), progress bars and gauges;
   [rules](rule.md), dividers; [text styles](text.md), Unicode's
   styled alphabets.
7. [Linting](lint.md): checking a figure, drawn or hand-made, for
   what breaks it on someone else's screen.
8. [Glyph sets](glyphs.md): width classes, the named glyph sets, and
   checking a set of one's own.

## Reference

- [The `tessella` command](cli.md): every command and option, exit
  statuses, pipelines.
- [The library](library.md): every factory, `Block`, `Raster`,
  `Width`, errors, the output rules, vendoring.
- [DESIGN.md](../DESIGN.md): the internal interfaces, and why the
  project is shaped as it is.

## Examples

Every figure in these pages is real output. The input files and the
Ruby scripts are in [examples/](../examples/); each `$` command runs
in that directory. `doc/check.rb` re-runs every one of them and
compares the output byte for byte:

```sh
ruby doc/check.rb            # report any figure that changed
ruby doc/check.rb --update   # rewrite the pages from what runs now
```
