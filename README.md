# tessella

Text figures for a monospace grid, in Unicode or pure ASCII: charts
(line, scatter, stairs, bar, histogram, box, stem and density plots,
on braille, block, dot, density or ASCII canvases, with scaled axes),
trees, tables, RFC-style bit-field diagrams, timing diagrams and
sequence diagrams, and the composition that frames them and sets
them side by side or stacked. The output is meant for documents
first, a terminal second: no trailing blank on any line,
no escape code unless colour is asked for, and a `--ascii` mode that
is ASCII from the first byte.

tessella has no runtime dependency: binning, percentiles and density
mapping are plain Ruby. The full guide, a page per module with real
renders and runnable [examples](examples/), is in [doc/](doc/README.md);
see [DESIGN.md](DESIGN.md) for the internal interfaces and the
decisions behind them.

## Install

tessella is not on rubygems.org, and it has no public remote. Install
it from a checkout of this repository:

```bash
cd tessella
make install
```

`make install` builds the gem and installs it for this user (`gem
install --user-install --local`). `make uninstall` removes it again.
Running `exe/tessella` directly out of a checkout, without installing,
also works.

## The library

```ruby
require "tessella"

chart = Tessella.line(x = nil, y, name: nil, **opts)   # also scatter,
                                             #   stairs, density
chart.add(x = nil, y, name: nil, color: nil, mark: nil) # another series
Tessella.stairs(x = nil, y, style: :post, **opts)       # or style: :pre
Tessella.bar(labels, values, **opts)
Tessella.histogram(values, bins: nil, closed: :left, **opts)
Tessella.box(names, samples, **opts)        # samples: Array of Arrays
Tessella.stem(values, scale: nil, **opts)   # stem-and-leaf

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

`mark:` (on `add`, and on `Tessella.line`, `.scatter`, `.stairs` and
`.density` for the first series) draws that series as one glyph in
the cell of each point, over whatever the cell holds, instead of the
kind's own line or dots: `chart.add(xs, ys, name: "measured", mark:
"●")` marks measured points on a fitted curve. The glyph is one
character, ASCII under `ascii: true`; the legend shows it before the
series' name. Bar, histogram, box and stem take no `mark:`.

Line and stairs take `area: true`, which fills under each series
from the floor up, as btop draws its graphs: every pixel column is a
bar, so a braille cell holds two bars of 0 to 4 dots (a block cell two
of 0 to 2), and a peak narrower than a column still shows. The y axis
then starts at 0 unless `ylim:` says otherwise. Under `color: true`
the cells take `gradient:`'s colours by height, bottom first
(default `[:green, :yellow, :red]`, equal bands; `false` keeps the
series' colour); without colour they are plain glyphs. A colour, in
`gradient:` as anywhere tessella takes one, is a name (`:red`,
`:green`, `:yellow`, `:blue`, `:magenta`, `:cyan`, `:white`), a
256-colour index (`0..255`) or a truecolor `"#rrggbb"`; a gradient
whose stops are all `#rrggbb` blends smoothly from the bottom row to
the top one instead of in bands.

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

Bar and histogram also take `orientation:` and `blocks:`.
`orientation: :vertical` draws columns rising from a floor, the value
axis on the left from 0 to the largest value; a bar chart's names go
under their columns when each fits, else its first and last name at
the two ends, and a histogram shows its axis's two ends. `blocks:` is
the glyph the bars are built of: `:eighths` (the default; `▁` to `█`
up a column, one column per character), `:braille` (one dot column
per bar, so two columns per character, 4 steps per cell; or, kept
horizontal, four bars per text row, each row named by the bars it
holds) or `:block`, also named `:quadrant` (the 2x2 quadrant glyphs,
as `canvas: :quadrant` for an area fill: two per character, 2
steps) or `:half` (half blocks, one bar per character: `▄`/`█` up a
column, 2 steps per cell, `▌`/`█` along a row, half a cell per step;
`canvas: :half` fills an area by halves). All need values of
0 or more; `:braille` and `:block` refuse `ascii: true`, `fill:`,
`eighths:` and `track:`. On the command line: `--orientation
horizontal|vertical` and `--blocks eighths|braille|block|quadrant|half`.

```text
$ printf 'ruby 12\nc 30\nrust 7.5\ngo 18\n' |
  tessella chart --kind bar --orientation vertical --height 5 --width 20
      ┌───────────────────┐
   30 │     ████          │
      │     ████          │
      │     ████      ████│
      │████ ████ ▂▂▂▂ ████│
    0 │████ ████ ████ ████│
      └───────────────────┘
       ruby   c  rust  go
```

Line, scatter, stairs and density take `orientation:` as well, the
direction their value axis runs: `:vertical` (the default) puts the
values up the vertical axis; `:horizontal` swaps the axes, values
along the horizontal one and x running up, so a horizontal chart of
`(x, y)` is the vertical chart of `(y, x)`. `xlim:`, `ylim:`,
`xlabel:` and `ylabel:` keep their meaning and follow their axis; an
`area:` fills from the left edge, its gradient running left to right.

Box takes `orientation: :vertical` (`--orientation vertical`) too:
each box stands three columns wide, whiskers running up and down
(`╶┬╴` at the maximum, `┌┴┐` at Q3, `├─┤` the median, `└┬┘` at Q1,
`╶┴╴` at the minimum), the value axis on the left with its two ends
and middle, the names under the boxes; `ylim:` sets its range, and a
median sharing a row with a box edge wins it.

`Tessella.stem` refuses a scale that is not positive, and a plot
that would need more than 1000 stems, one line each (raise `scale:`).

### Composing figures

Any figure -- a chart, a String of lines, a `Block` -- composes into
one, measured in display columns (CJK counts two, colour codes none):

```ruby
plot = Tessella.bar(%w[ruby c], [12, 30], width: 20)
fig = Tessella.frame(plot, title: "Load", style: :rounded)
puts Tessella.beside(fig, Tessella.caption("note", text: "n"),
                     align: :middle)
```

`frame(fig, title:, style:, pad:)` boxes one figure (style `:light`,
`:heavy`, `:double`, `:rounded`, `:dashed` (`┄┆`), `:dashed_fine`
(`┈┊`), `:heavy_dashed` (`┅┇`), `:heavy_dashed_fine` (`┉┋`),
`:double_h` (`╒═╕`, double horizontals), `:double_v` (`╓─╖`, double
verticals) or `:ascii`; a name may say `-` for `_`; or a custom set: six
glyphs `tl tr bl br h v`, as in `style: "╓╖╙╜─║"`, or a
`Tessella::Borders::Set`); `beside(*figs, gap:,
align:)` sets figures side by side (align `:top`, `:middle`,
`:bottom`); `stack(*figs, gap:, rule:, center:)` sets them one under
another; `indent(fig, prefix:)` prefixes every line (an empty line
gets the prefix without its trailing blank); `caption(fig, text:,
above:)` adds a centred line; `shadow(fig, glyph:)` adds a drop
shadow, `░` (`#` under `ascii: true`) one column right of every row
but the first and a bottom bar one row down reaching that column --
the geometry `tessella lint` checks. Each takes `ascii: true`, which draws
ASCII glyphs and refuses non-ASCII content, and returns a `Block`
(`lines`, `width`, `height`, `to_s`).

### Diagrams

Each diagram module reads the same small text formats the ascii-art
skill's scripts read, and returns a `Block`, so it composes like a
chart:

```ruby
Tessella.tree(outline, style: nil, ascii: false, root: nil)
Tessella.table(rows, header: true, style: nil, ascii: false,
               align: nil, title: nil, width: nil, min_width: 4,
               color: false)
Tessella::Table.parse(text, tsv: false)          # CSV/TSV -> rows
Tessella.bitfield(fields, word: 32, octets: false, ruler: true,
                  abbrev: false)
Tessella.wave(text, period: 4, ascii: false, ruler: false)
Tessella.seq(text, ascii: false, numbered: false, footer: false)
```

- **tree**: an indented outline, one node per line, the indent unit
  inferred from the first indented line; an optional `- `/`* `
  bullet, and `label  # note` notes aligned into one column. Styles
  `:light`, `:heavy`, `:rounded`; several top-level lines draw as a
  forest unless `root:` names one root for them.
- **table**: rows of Strings, the first the header unless `header:
  false`; styles `:light`, `:heavy`, `:double`, `:rounded`, the
  dashed four and `:double_h`/`:double_v` (with their mixed tees `╤ ╞
  ╪` and `╥ ╟ ╫`), `:ascii`,
  `:minimal` (dividers only) and `:markdown` (a GitHub pipe table), or
  a custom set of eleven glyphs, a frame's six then the tees `top_t
  bot_t sep_l sep_t sep_r` (`"╒╕╘╛═│╤╧╞╪╡"`). A
  column of numbers right-aligns; `align:` ("lrc", one letter per
  column) overrides; it also takes an Array of `:left`, `:right`,
  `:center`. `Table.parse` reads CSV (RFC 4180 quoting) or, with `tsv:
  true`, tab-separated text. A cell holding `"\n"` draws on several
  lines within its row, top-aligned. `width: N` fits the framed table
  to N columns by narrowing its widest column and word-wrapping that
  column's cells (a word too long breaks inside); below `min_width:`
  columns of text (4 by default) it is refused, naming the width it
  needs. ANSI colour in a cell takes no column and survives padding and
  wrapping, closed and reopened on each wrapped line; `color: true`
  sets the header in bold. Markdown refuses multi-line cells and
  `width:`.
- **bitfield**: `name:bits` lines or `[name, bits]` pairs, drawn as
  RFC 2360 draws them, always in ASCII: a bit ruler, `+-+` ticks, each
  name centred in its cell, a field longer than its row continued on
  the next. `word:` is 8, 16, 32 or 64; `octets:` ticks per byte; a
  name too wide for its cell is refused unless `abbrev:` truncates it,
  and a non-ASCII name is refused.
- **wave**: WaveDrom-like signals, `name: wave` per line in `0 1 p n
  x z = .`, bus labels after `|`, a lone `---` for a blank row; each
  step is `period:` columns (2 at least), `ruler:` numbers the steps.
- **seq**: `participant A`, `A -> B: call`, `A --> B: reply`, `A ->>
  B: async`, `A -> A: self`, `note over A[,B]: text`; columns widen
  to fit every label, and `numbered:` / `footer:` number the messages
  and repeat the participant boxes below.

Every one refuses bad input with an `ArgumentError` naming the line,
and under `ascii: true` draws ASCII glyphs and refuses non-ASCII text.

### Pictures

```ruby
Tessella.image(source, style: :ramp, width: 78, ramp: nil, gamma: 1.0,
               threshold: 0.5, dither: :fs, invert: false,
               edge_threshold: 0.3, ascii: false)
```

`source` is a `Tessella::Raster`, an IO, or a String of image bytes.
PGM/PPM and PNG are decoded with nothing installed; any other format
(JPEG, TIFF, WebP, ...) needs the `rmagick` gem, used when it is
installed and never required, and without it is refused with the
`magick IMAGE pgm:- | tessella image` pipe as the way round. Styles
trade tone for resolution: `ramp` and `blocks` give one tone per cell,
`half`, `quadrant`, `sextant` and `braille` pack 2 to 8 pixels into a
cell, and `edges` draws Sobel contours as `─ │ ╱ ╲`. `dither:` is
`:none`, `:fs` (Floyd-Steinberg), `:atkinson` or `:bayer`; `invert:
true` is for a light background. `ascii: true` allows only the `ramp`
style with an ASCII ramp. A picture that renders blank is refused,
naming the threshold to lower.

### Linting

```ruby
report = Tessella.lint(source, width: 78, prefix: "", web: false,
                       forbid: [], no_wide: false, ascii: false,
                       allow_mixed: false, fences: false, geometry: false,
                       borders: [])
report.findings   # => [#<data Tessella::Lint::Finding line=3, message="...">]
report.clean?     # => true when there is none
Tessella.alphabet(source)  # => "ascii", or "utf-8 box-drawing(12) ..."
```

`source` is a String or an IO. The lint checks a text figure for
what breaks it on someone else's screen: tabs, invisible glyphs,
trailing blanks, lines past `width` once `prefix` is drawn in front,
invalid UTF-8, ASCII box structure mixed with Unicode box drawing in
one figure, a vertical one column off its anchor on a few rows, and a
drop shadow (`░`) missing from a row or misplaced. `web: true` adds
glyphs some web renderers draw two cells wide; `no_wide: true` makes
every wide glyph an error, and `ascii: true` every non-ASCII one.
`forbid:` takes sequences, or presets naming a comment syntax (`xml`,
`c-block`, `c-line`, `python-doc`, ...), and flags lines that would
end the comment the figure sits in. A line reading
`artlint: allow-mixed` (or `tessella: allow-mixed`), in any comment
syntax, exempts the figure after it from the mixing check.

`fences: true` lints each fenced block of a Markdown text on its own,
with the text's line numbers, so prose and tables are not read as
art. `geometry: true` also checks that a box's sides stay in their
columns down to its bottom edge, and that a vertical or an arrow head
hangs from something above it rather than from blank space, for every
box-drawing set (light, heavy, double, rounded, dashed, mixed
junctions) and ASCII `+-|` boxes; `borders:` adds custom sets (names,
`Borders::Set`s or six-glyph Strings, as `style:` takes them).
`Tessella.alphabet` measures a file before a figure goes into it: a
file that is pure ASCII should get ASCII art.

### Glyph sets

```ruby
Tessella::Width.class_of("▒")              # => :A
Tessella::Glyphs.fetch(:meter, :arrow)     # => a GlyphSet: glyphs "▸▹"
Tessella::Glyphs.fetch(:ramp, :blocks).mixed?  # => true (░ N, ▒▓█ A)
```

Every glyph has a width class, as the ascii-art skill's palette names
them: N, narrow everywhere; A, East Asian Ambiguous (one column in
Western terminals, two in CJK-configured ones); W, always two.
`Tessella::Glyphs` names the sets the library draws with -- border
styles, fill patterns, meter fill/track pairs, rule lines, tone ramps
-- and computes each set's classes from Unicode 15.1, never by hand.
A set spanning two classes is *mixed*: fine in Western terminals, but
it changes length in CJK ones.

```text
tessella glyphs [KIND [NAME]]    # every set, a kind, or one set's glyphs
tessella glyphs --check GLYPHS   # the classes of a set of one's own;
                                 #   exit 1 when they are mixed
```

### The command line from Ruby

`require "tessella"` loads the library alone. The command classes
(`Tessella::CLI`, `Tessella::ChartCLI`, ...) and `optparse` come with
`require "tessella/cli"`, which loads the library too.

## The `tessella` command

```text
tessella COMMAND [options] [file]
tessella chart [options] [file]
```

The first argument names the command; `tessella --help` lists them:
`chart`, `compose`, `tree`, `table`, `bitfield`, `wave`, `seq`,
`image` and `lint`, each with its own `--help`. A file that cannot
be read is bad input (exit 1) in every command, a bad option a usage
error (exit 2).
`tessella --version` prints the version. No command, or an unknown
one, is a usage error (exit 2).

Reads one file argument or stdin (blank lines and `#` comments
skipped), draws one chart, and prints it. A line holding a comma
splits on commas, one holding a tab on tabs, and any other line on
runs of spaces, so a CSV or tab-separated label may hold spaces.
Columns by kind: line/scatter/stairs/density take one column of y
(against 1..n), two columns of x y, or more columns as x and one
series per further column; bar takes label and value, and refuses a
row with a third column (bad input, exit 1); histogram takes
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
  tessella chart --title trig --width 30 --height 6
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
$ tessella chart --kind bar --width 30 langs.csv
        ┌                              ┐
   ruby ┤██████████▍··············· 12
      c ┤██████████████████████████ 30
   rust ┤██████▌··················· 7.5
        └                              ┘
```

The same chart under `--ascii`:

```text
$ tessella chart --kind bar --ascii --width 30 langs.csv
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
`--xlim A,B`, `--ylim A,B`,
`--canvas braille|block|quadrant|half|dot|ascii|density`,
`--ascii`, `--color`, `--xscale ln|log2|log10`.

Kind-specific: `--bins N` and `--closed left|right` (histogram only);
`--style post|pre` (stairs only); `--blocks
eighths|braille|block|quadrant|half` (bar and histogram only);
`--orientation horizontal|vertical`
(every kind but stem: the direction the value axis runs, bars and
boxes horizontal by default, the plotted kinds vertical); `--area`
and `--gradient C,C,...`
(line and stairs only; each `C` a name, an index `0..255` or `#rrggbb`,
or `none` for the series' colour); `--scale N` (stem only); `--fill G`,
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
the first use of tessella's output is documents, where an escape code
is garbage.

### ASCII mode

`--ascii` (`ascii: true`) switches the canvas and the frame to
ASCII from the first byte: `+ - |` for the frame, `#` for bars, and an
ASCII glyph set for the plotted canvas instead of Unicode braille,
block or dot cells — no part draws Unicode and lets a later pass
rewrite it.

### `tessella compose`

```text
tessella compose frame   [--title T] [--style S] [--pad N] BLOCK
tessella compose beside  [--gap N] [--align A] BLOCK...
tessella compose stack   [--gap N] [--rule C] [--center] BLOCK...
tessella compose indent  --prefix STR BLOCK
tessella compose caption --text T [--above] BLOCK
tessella compose shadow  [--glyph G] BLOCK
```

Each BLOCK is a file, or `-` for stdin (once). `--style` takes a
style's name or six glyphs, as `style:` does. Every subcommand also
takes `--ascii` and `--max-width N`. Bad input -- a missing file, an
empty block, a tab, a non-ASCII byte under `--ascii`, output wider
than `--max-width` -- exits 1 naming the block and line; a usage
mistake (an unknown style or align, `--style` other than ascii with
`--ascii`, a wrong number of blocks) exits 2.

```text
$ tessella chart --kind bar --width 20 langs.csv > plot.txt
$ tessella compose frame --title Load plot.txt
```

### The diagram commands

```text
tessella tree     [--style S] [--ascii] [--root NAME] [file]
tessella table    [--tsv] [--no-header] [--style S|GLYPHS] [--ascii]
                   [--align SPEC] [--title T] [file]
tessella bitfield [--word N] [--octets] [--no-ruler] [--abbrev] [file]
tessella wave     [--period N] [--ascii] [--ruler] [file]
tessella seq      [--ascii] [--numbered] [--footer] [file]
tessella image    [--style S] [--width N] [--dither M] [--ramp STR]
                  [--gamma F] [--threshold F] [--edge-threshold F]
                  [--invert] [--ascii] [file]
```

Each reads its file or stdin and takes `--max-width N`, refusing
(exit 1) a figure wider than N columns. Bad input exits 1 naming the
line; a usage mistake exits 2.

```text
$ printf 'A -> B: request\nB --> A: ok\n' | tessella seq
```

### `tessella lint`

```text
tessella lint [--width N] [--prefix STR] [--ruler] [--forbid SEQ]...
              [--web] [--no-wide] [--ascii] [--allow-mixed]
              [--fences] [--geometry] [--border GLYPHS]...
              [file ...]
tessella lint --alphabet [file ...]
```

The command form of `Tessella.lint`, and the ascii-art skill's
`artlint.rb` under a new name, with its options and output kept:
findings go to stderr as `FILE:LINE: message` (`stdin` for stdin),
one per line; exit 0 when every input is clean, 1 on any finding or
an unreadable file (the other files are still linted), 2 on a usage
mistake. `--ruler` prints each line's width and the columns of its
verticals on stdout, which must agree down a figure. `--alphabet`
prints `FILE: ascii` or `FILE: utf-8 ...` on stdout, lints nothing
and exits 0. Its `--paranoid` is gone: `--ascii` is the flag.

```text
$ printf 'a\tb\n┌──┐ \n│ab │\n└──┘\n' | tessella lint --geometry
stdin:1: tab character
stdin:2: trailing whitespace
stdin:3: side of box opened at line 2 col 1 is off at col 4
stdin:3: connector '│' at col 5 hangs from ' '
```

## Relation to unicode_plot

tessella is a full rewrite, not a fork or a wrapper, of
[unicode_plot](https://github.com/red-data-tools/unicode_plot) (the
gem this project drew its chart kinds and canvases from). unicode_plot
serves as a test oracle only — every kind and canvas is compared
against it under test — and no code is copied from it; the ASCII
canvas's glyph rule in particular is original. Under unicode_plot's
own bar settings (`fill: "■"` for bars, `"▇"` for histograms, no
eighths, no track), tessella's output is byte-for-byte identical to
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
make bundle   # write dist/tessella.rb, the library as one file
```

See [DESIGN.md](DESIGN.md) for the module layout and interfaces, and
`make help` for every target.

## License

MIT. See [LICENSE](LICENSE).
