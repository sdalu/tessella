# inkchart

Charts for a monospace grid: line, scatter, stairs, bar, histogram,
box, stem and density plots, drawn in Unicode (braille, block, dot,
density canvases) or pure ASCII, with scaled axes. The output is meant
for documents first, a terminal second: no trailing blank on any line,
no escape code unless colour is asked for, and a `--ascii` mode that
is ASCII from the first byte.

inkchart has no runtime dependency: binning, percentiles and density
mapping are plain Ruby. See [DESIGN.md](DESIGN.md) for the internal
interfaces and the decisions behind them.

## Install

inkchart is not on rubygems.org, and it has no public remote. Install
it from a checkout of this repository:

```bash
cd inkchart
make install
```

`make install` builds the gem and installs it for this user (`gem
install --user-install --local`). `make uninstall` removes it again.
Running `exe/inkchart` directly out of a checkout, without installing,
also works.

## The library

```ruby
require "inkchart"

chart = Inkchart.line(x = nil, y, name: nil, **opts)   # also scatter,
                                             #   stairs, density
chart.add(x = nil, y, name: nil, color: nil, mark: nil) # another series
Inkchart.stairs(x = nil, y, style: :post, **opts)       # or style: :pre
Inkchart.bar(labels, values, **opts)
Inkchart.histogram(values, bins: nil, closed: :left, **opts)
Inkchart.box(names, samples, **opts)        # samples: Array of Arrays
Inkchart.stem(values, scale: nil, **opts)   # stem-and-leaf

chart.to_s                 # => String, already framed
chart.render(io = $stdout)
```

Options common to every kind, all optional: `title xlabel ylabel
width height xlim ylim canvas ascii color border xscale`. Defaults:
width 40, height 15, canvas `:braille` (`:ascii` when `ascii: true`),
`color: false`, border by kind. `xscale:` runs a series' x values
through a transform (`:ln`, `:log2`, `:log10`; `nil` the identity)
before limits and drawing. An unknown option, canvas, xscale name, or
(for stairs) style raises `ArgumentError` naming it, as do a width or
height that is not a positive Integer, x and y of different lengths,
and a value that is not a finite number (nil, a String, NaN,
±Infinity, or what an `xscale:` makes of an x of 0 or below).

`mark:` (on `add`, and on `Inkchart.line`, `.scatter`, `.stairs` and
`.density` for the first series) draws that series as one glyph in
the cell of each point, over whatever the cell holds, instead of the
kind's own line or dots: `chart.add(xs, ys, name: "measured", mark:
"●")` marks measured points on a fitted curve. The glyph is one
character, ASCII under `ascii: true`; the legend shows it before the
series' name. Bar, histogram, box and stem take no `mark:`.

Bar and histogram take three more options, all optional: `fill:` the
bar glyph (`█` by default, `#` under `ascii: true`), `eighths:` draw
the fractional last cell with `▏▎▍▌▋▊▉` (`true` by default, always
`false` under `ascii: true`), and `track:` the glyph filling the rest
of the bar's width (`·` by default, `.` under `ascii: true`; `nil` for
none).

Bar values may be negative. With at least one, the bar area splits at
a zero column into a negative and a positive part, each as wide as
its share of the values' span: negative bars grow left from zero,
positive ones right, and every value label follows the whole area.
A negative bar's fractional end is a half cell (`▐`), whole cells
under `ascii: true` or `eighths: false`:

```text
     ┌                              ┐
   a ┤█████████████████········· -6
   b ┤·················█████████ 3
   c ┤·························· 0
     └                              ┘
```

`Inkchart.stem` refuses a scale that is not positive, and a plot
that would need more than 1000 stems, one line each (raise `scale:`).

## The `inkchart` command

```text
inkchart [options] [file]
```

Reads one file argument or stdin (blank lines and `#` comments
skipped), draws one chart, and prints it. A line holding a comma
splits on commas, one holding a tab on tabs, and any other line on
runs of spaces, so a CSV or tab-separated label may hold spaces.
Columns by kind: line/scatter/stairs/density take one column of y
(against 1..n), two columns of x y, or more columns as x and one
series per further column; bar takes label and value; histogram takes
one column of samples; box takes one or more columns, one box per
column; stem takes one column, or two for the back-to-back form. A
first row that is not all numbers (for bar, a first row whose value
field is not a number) names the columns.

Three renders, byte for byte as printed.

Two named series, from a header row `x sin cos` and 101 rows of data
generated on the spot:

```text
$ ruby -e 'puts "x sin cos"; 0.step(10, 0.1) { puts [it.round(1),
    Math.sin(it), Math.cos(it)].join(" ") }' |
  inkchart --title trig --width 30 --height 6
                   trig
      ┌──────────────────────────────┐
    1 │⠉⠱⡤⠊⠉⠉⢢⡀        ⢠⠊⠉⠉⠢⡴⠊⠉⠙⢢    │ sin
      │ ⡴⠉⢆   ⠘⡄      ⡰⠁   ⡔⠙⣄   ⠱⡀  │ cos
      │⡜  ⠈⢆   ⠸⡄    ⡜⠁  ⢀⠞  ⠈⡆   ⠱⡀ │
      │⠉⠉⠉⠉⠉⢏⠉⠉⠉⠙⡍⠉⠉⡽⠉⠉⠉⢉⡝⠉⠉⠉⠉⠙⢏⠉⠉⠉⠹⡉│
      │     ⠈⢇   ⠙⡄⡜   ⢀⠎      ⠘⢄   ⠱│
   -1 │       ⠱⣄⣀⣠⠎⠢⣀⣀⡰⠊        ⠈⠣⣄⣀⡠│
      └──────────────────────────────┘
      0                             10
```

A two-column CSV, `langs.csv`, holding `lang,loc`, `ruby,12`, `c,30`
and `rust,7.5`, drawn as a bar chart with the house defaults
(`eighths` on, `·` track):

```text
$ inkchart --kind bar --width 30 langs.csv
        ┌                              ┐
   ruby ┤██████████▍··············· 12
      c ┤██████████████████████████ 30
   rust ┤██████▌··················· 7.5
        └                              ┘
```

The same chart under `--ascii`:

```text
$ inkchart --kind bar --ascii --width 30 langs.csv
        +                              +
   ruby |##########................ 12
      c |########################## 30
   rust |#######................... 7.5
        +                              +
```

### Options

Common to every kind: `--kind
line|scatter|stairs|density|bar|histogram|box|stem` (default `line`),
`--width N`, `--height N`, `--title S`, `--xlabel S`, `--ylabel S`,
`--xlim A,B`, `--ylim A,B`, `--canvas braille|block|dot|ascii|density`,
`--ascii`, `--color`, `--xscale ln|log2|log10`.

Kind-specific: `--bins N` and `--closed left|right` (histogram only);
`--style post|pre` (stairs only); `--scale N` (stem only); `--fill G`,
`--no-eighths` and `--track G|none` (bar and histogram only, as above).
`--help` and `--version` print and exit. An option given to a kind
that does not take it is a usage error (exit 2) naming both; a bad
value for one a kind does take surfaces as the chart's own
`ArgumentError`, also exit 2. Bad input (a non-number where a number
is due, a missing field) exits 1, naming the row and the field.

### Colour

Colour is off by default: `--color` on the command line, `color:
true` in the library, turns on ANSI escapes for the chart's cells;
the frame, labels and legend stay plain. The default is off because
the first use of inkchart's output is documents, where an escape code
is garbage.

### ASCII mode

`--ascii` (`ascii: true`) switches the canvas and the frame to
ASCII from the first byte: `+ - |` for the frame, `#` for bars, and an
ASCII glyph set for the plotted canvas instead of Unicode braille,
block or dot cells — no part draws Unicode and lets a later pass
rewrite it.

## Relation to unicode_plot

inkchart is a full rewrite, not a fork or a wrapper, of
[unicode_plot](https://github.com/red-data-tools/unicode_plot) (the
gem this project drew its chart kinds and canvases from). unicode_plot
serves as a test oracle only — every kind and canvas is compared
against it under test — and no code is copied from it; the ASCII
canvas's glyph rule in particular is original. Under unicode_plot's
own bar settings (`fill: "■"` for bars, `"▇"` for histograms, no
eighths, no track), inkchart's output is byte-for-byte identical to
unicode_plot's.

A few places depart from unicode_plot on purpose: the density canvas
honours sizes below 5 (unicode_plot clamps to 5); histogram labels
survive bins of width 10 or more (unicode_plot crashes there); and an
axis extreme prints `10`, not `10.0`, while a plotted value keeps its
own form; stem leaves are exact (`0.3` at scale 1 is leaf 3, where
unicode_plot prints 2); constant data of 1e16 or more draws (it
crashes unicode_plot); negative bars draw (unicode_plot refuses
them); and labels in wide characters (CJK) are measured in display
columns. See [DESIGN.md](DESIGN.md) for why.

## Development

```bash
make check    # preflight: every file parses, RuboCop clean
make tests    # run the suite; ORACLE=path/to/gems also runs the
              # unicode_plot comparisons (unicode_plot is never a
              # runtime or install dependency)
make bundle   # write dist/inkchart.rb, the library as one file
```

See [DESIGN.md](DESIGN.md) for the module layout and interfaces, and
`make help` for every target.

## License

MIT. See [LICENSE](LICENSE).
