# The library

```ruby
require "tessella"
```

loads the drawing library and nothing else: no command line, no
option parser, no gem. Every factory is a module function on
`Tessella`; its result prints with `puts`.

## Factories

### Charts

```ruby
Tessella.line(x = nil, y, name: nil, mark: nil, **opts)    # => Chart
Tessella.scatter(x = nil, y, name: nil, mark: nil, **opts)
Tessella.stairs(x = nil, y, name: nil, mark: nil, style: :post, **opts)
Tessella.density(x = nil, y, name: nil, mark: nil, **opts)
Tessella.bar(labels, values, **opts)
Tessella.histogram(values, bins: nil, closed: :left, **opts)
Tessella.box(names, samples, **opts)     # samples: Array of Arrays
Tessella.stem(values, other = nil, scale: nil, **opts)
Tessella.heatmap(matrix, xlabels: nil, ylabels: nil, cell_width: 2,
                 colormap: nil, min: nil, max: nil, **opts)
Tessella.candlestick(x, open:, high:, low:, close:, **opts)
Tessella.pie(labels, values, donut: false, rim: :cells, **opts)

chart.add(x = nil, y, name: nil, color: nil, mark: nil)  # => chart
chart.to_s                  # => String, framed, "\n"-terminated
chart.render(io = $stdout)  # prints to_s
```

`x` defaults to `1..y.length`. `add` takes another series on a line,
scatter, stairs or density chart. `stem`'s `other` is the second set
of a back-to-back plot. `opts`, their defaults, and the bar options
(`fill:`, `eighths:`, `track:`) are in [charts](charts.md#common-options).

### Composition

```ruby
Tessella.frame(fig, title: nil, style: nil, pad: 1, fill: nil,
               halo: true, ascii: false)
Tessella.beside(fig, fig, ..., gap: 1, align: :top, ascii: false)
Tessella.stack(fig, fig, ..., gap: 0, rule: nil, center: false,
               ascii: false)
Tessella.grid(fig, fig, ..., columns: 2, gap: 2, row_gap: 1,
              align: :top, ascii: false)
Tessella.indent(fig, prefix:, ascii: false)
Tessella.caption(fig, text:, above: false, ascii: false)
Tessella.shadow(fig, glyph: nil, ascii: false)
Tessella.fill(fig, pattern: nil, halo: true, ascii: false)
```

Each takes any figure (a `Block`, a `String`, a chart) and returns a
`Block`. See [composition](composition.md).

### Diagrams and pictures

```ruby
Tessella.tree(outline, style: nil, ascii: false, root: nil)
Tessella.table(rows, header: true, style: nil, ascii: false,
               align: nil, title: nil, width: nil, min_width: 4,
               color: false)                # min_width: N, or [N, ...]
Tessella::Table.parse(text, tsv: false)        # => Array of rows
Tessella.bitfield(fields, word: 32, octets: false, ruler: true,
                  abbrev: false)
Tessella.wave(text, period: 4, ascii: false, ruler: false)
Tessella.seq(text, ascii: false, numbered: false, footer: false)
Tessella.image(source, style: :ramp, width: 78, ramp: nil, gamma: 1.0,
               threshold: 0.5, dither: :fs, invert: false,
               edge_threshold: 0.3, ascii: false)
Tessella.meter(fraction, style: :block, width: 20, title: nil,
               title_width: nil, label: true, brackets: true,
               orientation: :horizontal, height: 8, ascii: false)
Tessella.sparkline(values, width: nil, min: nil, max: nil, ascii: false)
Tessella.rule(width: 78, ornament: nil, style: :light, ascii: false)
Tessella.text(str, style:, strict: false, ascii: false)  # => String
```

The figures return a `Block`. Pages: [tree](tree.md), [table](table.md),
[bitfield](bitfield.md), [wave](wave.md), [seq](seq.md),
[images](images.md), [sparkline](sparkline.md), [meter](meter.md),
[rule](rule.md),
[text](text.md). `text` returns a String, not a Block.

### Lint

```ruby
Tessella.lint(source, width: 78, prefix: "", web: false, forbid: [],
              no_wide: false, ascii: false, allow_mixed: false,
              fences: false, geometry: false, borders: [])
                                   # => Tessella::Lint::Report
Tessella.alphabet(source)          # => "ascii" or "utf-8 <classes>"
```

`source` is a String or an IO. A report has `findings` (each a
`Finding` with `line` and `message`), `clean?`, and `rulers` (each a
`Ruler` with `line`, `width` and `verticals`). See [lint](lint.md).

## Values

### `Tessella::Block`

```ruby
block.lines            # => Array of String
block.width            # => Integer, display columns
block.height           # => Integer
block.to_s             # => String, "\n"-terminated
block.check_width!(n)  # raises ArgumentError if wider than n
Tessella::Block.from(figure)  # a Block from a Block, String or chart
```

A block has no trailing blank on any line, no trailing blank line,
and no tab.

### `Tessella::Raster`

```ruby
Tessella::Raster.new(width:, height:, luma:)
Tessella::Raster.decode(bytes)   # PNM or PNG; others via rmagick
```

A greyscale image: `luma` is `width * height` Floats in 0..1, row by
row from the top. See [images](images.md#sources).

### `Tessella::Borders::Set`

```ruby
Tessella::Borders::Set.new(tl, tr, bl, br, h, v)
```

A custom border, for `frame`'s and `table`'s `style:` and `lint`'s
`borders:`. A six-glyph String in the same order does the same job;
a table needs eleven, its five tees after these six. See
[custom borders](composition.md#custom-borders).

### `Tessella::Width`

```ruby
Tessella::Width.of("日本")         # => 4
Tessella::Width.of("\e[1mab\e[0m") # => 2
```

The display width of a string: the columns a terminal gives it, wide
characters two, combining marks and ANSI escapes none. Every figure
is measured with it, which is why CJK labels line up.
`Tessella::Width.class_of(char)` is a character's width class, `:N`,
`:A` or `:W`; see [glyph sets](glyphs.md). Width counts grapheme
clusters: an emoji sequence joined by ZWJ, or skin-toned, is one
glyph, two columns wide.

### Width targets

```ruby
Tessella.target = :cjk           # :term (default), :cjk or :web
Tessella::Target.with(:web) { ... }
```

The target the figures are drawn for, per fiber; see
[width targets](targets.md).

### `Tessella::Glyphs`

```ruby
Tessella::Glyphs.fetch(kind, name)  # => GlyphSet
Tessella::Glyphs.all                # => every GlyphSet
glyph_set.glyphs; glyph_set.classes; glyph_set.mixed?
```

The named glyph sets the library draws with, and their width classes.
See [glyph sets](glyphs.md).

## Errors

Every refusal is an `ArgumentError` with a message that names what is
wrong — the option, the value, the line of input — raised before
anything is drawn. A figure is either right or not returned. A value
that cannot be drawn (not finite, out of range, out of order) raises
`Tessella::ValueError`, a subclass, so a caller can tell bad data
from a bad call; the command line exits 1 for the first and 2 for
the second.

```ruby
# frozen_string_literal: true

# examples/refusals.rb: what the library refuses, and how it says so.
require "tessella"

[
    -> { Tessella.line([1, 2, 3], [1, 2]) },
    -> { Tessella.bar(%w[a b], [1, Float::NAN]) },
    -> { Tessella.line([1, 2], width: 0) },
    -> { Tessella.line([1, 2], colour: true) },
    -> { Tessella.tree("a\n   b\n  c") },
    -> { Tessella.frame("é", ascii: true) }
].each do |call|
    call.call
rescue ArgumentError => e
    puts "#{e.class}: #{e.message}"
end
```

```text
$ ruby refusals.rb
ArgumentError: x and y differ in length: 3 and 2
Tessella::ValueError: value must be a finite number: NaN
ArgumentError: width must be a positive Integer: 0
ArgumentError: unknown option: :colour
ArgumentError: line 3: indentation is not a multiple of 3
ArgumentError: block 1 is non-ASCII under ascii: true
```

## The rules every figure keeps

- **No trailing blank** on any line, and no trailing blank line.
- **No escape code** unless `color: true`.
- **No tab, no invisible glyph.** A blank cell is a space (U+0020),
  never the empty braille pattern U+2800.
- **`ascii: true` is ASCII from the first byte:** a figure is drawn
  in ASCII glyphs, not drawn in Unicode and rewritten after, and any
  text given to it that is not ASCII is refused. A bit field is
  always ASCII.
- **Values as given:** `12` prints `12`, not `12.0`, and a Float
  keeps its digits.

These are what make a figure safe to paste into a README, a commit
message, a source comment or a man page.

## Vendoring

tessella has no runtime dependency, so it can travel as one file:

```sh
make bundle    # writes dist/tessella.rb: the library and the CLI
```

`dist/tessella.rb` is the library followed by the command line, in
load order. Copy it into a project and `require_relative` it.
