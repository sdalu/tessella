# tessella — design

Text figures for a monospace grid, drawn in Unicode or pure ASCII, for
documents first and terminals second. Plain Ruby 3.4, no runtime
dependency. It draws charts (line, scatter, stairs, bar, histogram,
box, stem and density plots with scaled axes, on braille, block, dot,
ASCII or density canvases), trees, tables, bit-field, timing and
sequence diagrams, and composes any of them into one figure.

## One library, one command per module

A chart, a table, a tree and a timing diagram need the same parts: a
grid of cells, display width, a frame, an ASCII glyph set drawn from
the first byte. They live in one library so those parts are written
once, gated once and kept to the same rules, rather than copied into
a script per figure. Each drawing module adds factories on `Tessella`
and one command to `tessella`; factory names are unique across
modules (a framed block will be `frame`, since `box` is the box
plot), and the command is the first argument, so one module's options
never collide with another's.

This note fixes the internal interfaces the parts are built against.
Each part has one owner file set; a part may rely only on what is
written here about another, so they can be built and tested apart.

## Rules that hold in every part

- **No runtime dependency.** Statistics, scaling and drawing are plain
  Ruby; the gemspec lists none. unicode_plot is a *test oracle* only
  (test/oracle.rb), and no code is copied from it.
- **Output is document-safe by construction.** No trailing blank on any
  line, no ANSI escape unless `color: true`, no tab, no invisible
  glyph (but U+FE0E after an emoji-capable glyph under target `:web`,
  "Width targets"); a blank cell is U+0020, never U+2800. `ascii: true` output is
  ASCII-only from the first byte: no part draws Unicode and lets a later
  pass rewrite it.
- **Values as given.** An Integer label stays an Integer (`12`, not
  `12.0`); a Float keeps its digits.
- **Two entries, one load order each.** `lib/tessella.rb` requires the
  library's files, in dependency order, with the standard library it
  needs (`zlib`) above them; `lib/tessella/cli.rb` requires the library,
  `optparse`, and the command line's files (`lib/tessella/cli/`), so
  `require "tessella"` loads no command line and no option parser. No
  other file calls `require` or `require_relative`, except
  `rmagick_reader.rb`, which loads the optional rmagick gem when an
  image needs it ("Images"). `tools/bundle.rb` follows the two entries,
  in that order, to concatenate library and command line into one file
  for vendoring.
- **House Ruby**: the ruby skill (`.rubocop.yml` is its gate, copied
  here): 4-space indent, 80 columns, methods of 10 lines or fewer,
  classes of 100 or fewer, double quotes, `it` for a single block
  parameter.

## Layout

```text
lib/tessella.rb            the public entry: requires, Tessella.<kind>
lib/tessella/version.rb    VERSION, the one place it is written
lib/tessella/error.rb      Tessella::Error < StandardError
lib/tessella/check.rb      the argument checks every kind shares
lib/tessella/target.rb     where a figure is read: term, cjk, web
lib/tessella/width.rb      display width: columns a terminal gives text
lib/tessella/width_class.rb width classes N, A, W (Unicode 15.1)
lib/tessella/glyphs.rb     the named glyph sets and their classes
lib/tessella/meter.rb      a one-line meter (progress bar, gauge)
lib/tessella/rule.rb       a divider line
lib/tessella/text.rb       text styles; text_forms.rb: their tables
lib/tessella/borders.rb    border glyph sets: light heavy double rounded ascii
lib/tessella/block.rb      Tessella::Block: a finished figure as lines
lib/tessella/compose.rb    frame, beside, stack, indent, caption
lib/tessella/cell.rb       Tessella::Cell (Data: char, color), Cell.blank
lib/tessella/stats.rb      binning, percentiles, transforms
lib/tessella/axis.rb       limits, nice rounding, number labels
lib/tessella/color.rb      colour names to ANSI, and nothing else
lib/tessella/canvas.rb     the base grid
lib/tessella/canvas/*.rb   braille, block, half, eighths (fills
                           only), dot, ascii, density, and area (the
                           fill under a curve, every type)
lib/tessella/frame.rb      border, labels, title, legend, render
lib/tessella/chart.rb      shared options, series, render entry
lib/tessella/kinds/*.rb    one file per kind
lib/tessella/<name>.rb     tree, table, bitfield, wave, seq, image: one
                           file per module (table_cells.rb: table's
                           multi-line cells, fitting and wrapping)
lib/tessella/raster.rb     Raster: a greyscale image; PNM; the decoder
                           dispatch
lib/tessella/png.rb        the built-in PNG decoder
lib/tessella/rmagick_reader.rb
                           every other format, through optional rmagick
lib/tessella/lint.rb       Tessella.lint and .alphabet: tables, options
lib/tessella/lint/*.rb     one file per check (lines, shadows, mixing,
                           drift, geometry), fences, alphabet, and the
                           runner that sequences them
lib/tessella/cli.rb        the command line's entry: loads the library,
                           optparse, and lib/tessella/cli/
lib/tessella/cli/<name>.rb `tessella <name>`: one file per command
                           (compose_options.rb, lint_options.rb: their
                           commands' options)
lib/tessella/cli/main.rb   `tessella`: dispatches on the command
exe/tessella               the command line
tools/bundle.rb            single-file build for vendoring
test/                      minitest; test/oracle.rb loads unicode_plot
```

## Blocks and composition

Every module's result can become an `Tessella::Block`: a finished
figure as lines of text, measured in display columns (`Width`, which
also skips ANSI colour codes, so a coloured chart composes by what it
shows). Composition takes any figure -- a Block, a String, a chart --
through `Block.from`, and returns a Block:

```ruby
Tessella.frame(fig, title: nil, style: nil, pad: 1, ascii: false)
Tessella.beside(fig, fig, ..., gap: 1, align: :top, ascii: false)
Tessella.stack(fig, fig, ..., gap: 0, rule: nil, center: false,
               ascii: false)
Tessella.indent(fig, prefix:, ascii: false)
Tessella.caption(fig, text:, above: false, ascii: false)
Tessella.shadow(fig, glyph: nil, ascii: false)  # ░ right and below
Tessella.grid(fig, ..., columns: 2, gap: 2, row_gap: 1, align: :top)
    # rows of figures, from beside and stack (compose_grid.rb)
Tessella.fill(fig, pattern: nil, ascii: false)  # enclosed blanks: the
    # cells a flood from the figure's edge through blanks cannot reach
block.lines; block.width; block.height; block.to_s
block.check_width!(max)     # ArgumentError naming the line and width
```

A block is never rewritten, only padded on the right, so its own
alignment survives every composition; stack's `center:` is the one
shift, of a whole block at once. A block's trailing blank lines are
dropped, a tab is refused (its width belongs to the viewer), and so
is an empty block. Border glyphs come from `Borders`, shared with
every framed figure; under `ascii: true` the set is `ascii` and any
other style, block or text holding a non-ASCII character is refused
rather than rewritten. These rules, and the exact output, are the
ascii-art skill's compose.rb's, which `tessella compose` replaces
byte for byte; its lint pass stays in the skill. One departure:
stack's `gap:` without a rule is N blank rows between blocks, as
compose.rb's help said, where its code put 2N (N on each side of a
rule that was not there).

Besides its named sets, `Borders` takes a custom one: a
`Borders::Set` or a String of six glyphs in its order (`tl tr bl br
h v`), or eleven for a table, whose last five are its tees (`top_t
bot_t sep_l sep_t sep_r`). A String that is a style's name is that
style; each glyph must be one visible column, and ASCII under `ascii:
true`. Named styles keep their rule under `ascii: true` (a frame
refuses them, a table draws `ascii`), but a custom set is never
silently replaced: it is drawn if ASCII and refused if not.

## Diagram modules

`tree`, `table`, `bitfield`, `wave` and `seq` began as the ascii-art
skill's generator scripts and are ported from them, not redesigned:
each was gated by byte parity with its script (output and exit
status, 47 to 77 cases each) before it replaced it. Each reads the
text format its script read, returns a `Block`, measures with
`Width`, and refuses bad input with an `ArgumentError` naming the
line. Where a port departs from its script, it is to keep a library
rule:

- **ASCII while drawing.** The scripts relied on a later artlint pass
  to catch a non-ASCII label under `--ascii`; the library refuses it
  while drawing, as every part does.
- **One exit-status contract.** A file that cannot be read is bad
  input (exit 1) in every command; three scripts made it a usage error.
  A wave `--period` below 2 is a usage error: a step of one column
  cannot hold a clock's rise and its fall.
- **No trailing blank row.** A wave ending on `---` loses that last
  blank row, as every block drops its trailing blank lines.
- **Table's own CSV reader.** In Ruby 3.4 `csv` is a bundled gem, not
  standard library, so a dependency; `Table.parse` is a short RFC 4180
  reader instead, held to `CSV.parse`'s records by test.
- **Tables past the script.** Beyond the port, a table takes
  multi-line cells, fits a width by narrowing the widest column a
  column at a time, so the widest ones converge downwards and a narrow
  one is never cut first (wrapping their cells, refusing only when
  every column is at `min_width:` or its natural width, rather than
  returning something wider than asked). It narrowed the widest column
  alone at first; a real climat table, whose two long columns together
  held the overflow, was refused for no reason, so the rule changed.
  It keeps ANSI colour in
  cells, closing and reopening it across a wrap so every line stands
  alone: what climat's tables need to move off tty-table. The script
  printed a newline in a CSV field raw, breaking the frame.
- **Bitfield is ASCII by genre.** RFC 2360 diagrams are ASCII; there
  is no Unicode path to keep in step.

The lint pass the scripts ran on their output (artlint) stays in the
skill: it is a policy tool for documents, not part of drawing.

## Images

`Tessella.image` draws a picture as text, from a `Raster`: width,
height, and luma in 0..1, colour folded by Rec. 601, alpha composited
over black so a transparent pixel is empty. `Raster.decode` picks the
decoder by the bytes' own signature:

- **PNM and PNG, always.** PGM/PPM is what the ascii-art skill's
  img2art.rb read, so its pipelines keep working with nothing
  installed; PNG covers screenshots, plots and logos, the usual
  sources, in plain Ruby over `zlib`, which ships with Ruby.
- **Everything else, through rmagick when it is installed.** A soft
  dependency, never declared in the gemspec: `rmagick_reader.rb` loads
  it only when such an image arrives, and without it the image is
  refused, naming the gem and the `magick ... pgm:-` pipe instead. A
  required RMagick would be a C extension built against ImageMagick at
  install, the kind of dependency the project exists to avoid.

`style: :octant` (`image_octant.rb`) adds Unicode 16's octants,
2x4 solid pixels per cell: the block holds 230 of the 256 patterns
in bit order, the other 26 being older glyphs (`█ ▀ ▌`, the
quadrants, quarter blocks), so the table is computed from that rule
and a 26-entry list, checked against the Unicode 16 names. Named
ramps come from the glyph registry.

The rendering is the skill's img2art.rb, ported byte for byte (182
cases): its sampling, dithering (Floyd-Steinberg, Atkinson, Bayer) and
glyph tables. Where it differs, it keeps a library rule: a blank
braille cell is a space, never U+2800; trailing blanks go (its `--pad`
is dropped, composition pads); `ascii: true` allows only the ramp style
with an ASCII ramp; and a picture that renders blank is refused,
naming the threshold to lower, rather than returned as nothing.

## Lint

`Tessella.lint` is the ascii-art skill's `artlint.rb`, ported so the
library ships the check its own output is held to, and so the skill
and the skills shelf (its README gate, the markdown skill, the evals)
call one installed command instead of a script by path. Its output is
a contract parsed elsewhere, kept byte for byte: `NAME:LINE: message`
on stderr, `--ruler` and `--alphabet` on stdout, exit 0 clean and 1 on
any finding. The port was checked against artlint.rb itself over
1,410 files of the shelf and this repository under eight flag sets,
identical on stdout, stderr and exit status; the suite carries the
skill's own lint fixtures and the eval fixtures' planted defects.

Two departures, each an addition rather than a change:

- **`fences: true`.** A Markdown file linted whole reads its prose and
  tables as art; the shelf's README gate split out each fence by hand
  to avoid that. The lint now does it, keeping the file's line
  numbers, and an allow-mixed marker just before a fence exempts it.
- **`geometry: true`**, from the shelf's `check-readme.py`: box sides
  that wander a column, and connectors hanging from blank space or a
  plain edge -- the commonest hand-drawn defect, which artlint did not
  measure. It is off by default because it reads every `│` and `+` as
  structure, so a Markdown table or a prose `|` would be flagged,
  and turning it on would have changed every existing lint result
  (the eval fixtures expect exactly their planted findings).
  check-readme.py knew only the light set and read a rounded box's
  sides as connectors hanging from its corners; here each glyph of
  U+2500..U+257F is read by its arms (up, down, left, right, from its
  Unicode name), so heavy, double, rounded, dashed and mixed junctions
  are one rule, and `borders:` declares custom sets whose glyphs take
  the arms of their roles (a glyph used for several roles plays all
  of them). It measures display columns, not characters, and does not
  flag a lifeline continuing under a horizontal that crosses it; on
  the light set it otherwise reports what `check-readme.py` reports
  (157 of 161 shelf files identical, the 4 others all such
  crossings), and every frame and table tessella draws, in every
  style, passes it.

`--paranoid`, an older name for `--ascii`, was dropped. The display
width tables are `Width`'s, so the lint and the figures it checks
count the same columns.

## Glyphs

`Width.class_of` gives a glyph's width class -- `:N`, `:A` (East
Asian Ambiguous) or `:W` -- from Unicode 15.1's EastAsianWidth.txt,
the ambiguous ranges generated into `width_class.rb` beside Width's
own tables. `Glyphs` (`glyphs.rb`) is the registry of named sets: the
border styles (read from `Borders`), fill patterns, meter pairs, rule
lines and ramps, from the ascii-art skill's palette and ui.md. Each
set's classes are computed, so the skill's references can query them
(`tessella glyphs`) instead of keeping a hand-typed copy, and a set
that mixes classes says so. Drawing modules take their glyphs from
here, so a new named set is one entry, not a constant per module.
Each set says which width targets it is safe for (`targets`): term,
cjk without an ambiguous glyph, web without a wide or emoji-capable
one.

## Width targets

`Target` (`target.rb`) names where a figure is read -- `:term`,
`:cjk`, `:web` -- held in fiber storage (`Target.with`,
`Tessella.target=`, the CLI's leading `--target` or
`TESSELLA_TARGET`), so no signature carries it. Three things read it,
and nothing else: `Width.char`, which gives an ambiguous glyph two
columns under `:cjk` (`Width.base` keeps the Western width, which
width classes are read from); every module's `ascii:` default, true
under `:cjk`, where the text checks (`Check.ascii!`, `Compose.text!`,
the tree's and the CLI's) stand down, so ASCII structure holds any
text; and `Block#to_s` / `Frame#to_s`, which under `:web` put U+FE0E
after each emoji-capable glyph (`Target.adapt`). Unicode boxes are not
kept aligned under `:cjk` by doubling: a box glyph two columns wide
beside single spaces cannot line up in trees, waves and chart axes,
so the structure turns ASCII instead. Width.of sums grapheme clusters:
an emoji sequence (ZWJ, skin tone) is one wide glyph.

## Meters and rules

`Tessella.meter` (`meter.rb`) draws one line: an optional title, the
bar in brackets, the percentage. Its fill/track pairs are the
registry's meter sets, so a style is one entry in `Glyphs::METERS`;
a pair of one's own is refused when its two glyphs differ in width
class, because such a bar changes length as it fills in a CJK
terminal and the label after it drifts. It doubles as the gauge
other libraries have: a gauge is a meter with a title.
`orientation: :vertical` (`meter_upright.rb`) stands it up, a
column filled from the bottom; several side by side are `compose
beside`'s, not a meter option.
`Tessella.rule` (`rule.rb`) is a divider in a registry rule style,
an ornament centred by display width.

## Text styles

`Tessella.text` (`text.rb`) maps characters through tables in
`text_forms.rb`, generated from Unicode 16's names and decomposition
tags (`<font>`, `<super>`, `<sub>`, `<circle>`, `<square>`, `<wide>`),
never by code point offset: the Mathematical Alphanumeric block has
reserved holes (italic h, script B E F H I L M R e g o, fraktur C H I
R Z, double-struck C H N P Q R Z) whose letters live in Letterlike
Symbols, and an offset table would emit the reserved code points.
The ordinal indicators `ª º` share `<super>` with `ᵃ ᵒ` and are left
out. `:plain` is every table reversed, so it undoes exactly what the
library produces.

## Stats and Axis

```ruby
Tessella::Stats.histogram(values, bins: nil, closed: :left)
    # => Tessella::Stats::Histogram (Data: edges, counts, closed)
    #    bins: nil = the count unicode_plot picks for the same data;
    #    edges ascending, counts.size == edges.size - 1; :left means
    #    [a, b), :right (a, b]; every value lands in exactly one bin
Tessella::Stats.percentiles(values, ps)   # ps in 0..100, linear
    # interpolation between order statistics (the definition
    # enumerable-statistics uses), => Array of Float
Tessella::Stats.transform(name)           # :identity :ln :log2 :log10
    # => a callable; nil and :identity are the identity
Tessella::Axis.limits(values, lim = nil)  # => [lo, hi]
    # lim [a, b] given and not [0, 0]: returned as is; otherwise the
    # data's extent widened to round values exactly as unicode_plot
    # widens it (its axis labels are the oracle)
Tessella::Axis.label(number)              # => String for a value
    # label (a bar's value): Integer as is; Float in the shortest form
    # that round-trips, no exponent for |x| in 1e-4...1e15
Tessella::Axis.tick(number)               # => String for an axis
    # extreme: as label, but a whole Float drops its ".0" (limits are
    # always Floats; 10 not 10.0, as unicode_plot prints them)
```

## Canvas

A grid of character cells, each cell a block of pixels; data coordinates
map onto pixels, pixel (0, 0) is the bottom-left.

```ruby
Tessella::Canvas.build(type, width:, height:, xlim:, ylim:)
    # type :braille (2x4 px per cell), :block or :quadrant (2x2),
    #   :half (1x2, ▀▄█; :half_wide 2x1, ▌▐█, for a bar), :dot (1x2),
    # :ascii (3x3), :density (1x2, glyph by hit count)
canvas.width, canvas.height              # cells
canvas.pixel_width, canvas.pixel_height
canvas.point(x, y, color: nil)           # data coordinates; outside
canvas.line(x0, y0, x1, y1, color: nil)  #   the limits: clipped
canvas.points(xs, ys, color: nil)
canvas.lines(xs, ys, color: nil)         # joins consecutive points
canvas.area(xs, ys, color: nil, across: false)  # fills each pixel
    # column the path spans from the floor to the curve (canvas/area.rb),
    # or with across: each pixel row from the left edge; color: a
    # colour, or a callable cell row (0 the top) / column -> colour
canvas.row_bar(py, length, color: nil)   # pixel-level bars, for the
canvas.column_bar(px, height, color: nil) #   bar layouts
canvas.rows                              # => Array (top row first) of
    # Array of Tessella::Cell (Data: char, color); char " " is blank
canvas.annotate(col, row, text, color: nil)  # writes text into cells
canvas.mark(x, y, char, color: nil)  # char in the cell holding (x, y),
    # over what the cell draws; outside the limits: nothing
```

Colour per cell: the last colour drawn into a cell wins. `:ascii` and
`:density` draw only ASCII, resp. `" ░▒▓█"` and ASCII under ascii mode
(the density canvas takes `ascii: true` to use `" .:+#"`).

## Frame and Color

The frame turns a body of cells into text; it knows nothing of data.

```ruby
Tessella::Frame.new(
    body:,              # Array of rows of Tessella::Cell, equal width
    border: :box,       # :box (full frame), :bar (corners + left ticks
                        #   on every row, as a bar chart), :none
    ascii: false,       # + - | instead of box drawing
    color: false,       # ANSI escapes for cell and label colours
    title: nil, xlabel: nil, ylabel: nil,
    left: {},           # row index => text, right-aligned before the
                        #   frame (y-axis labels, bar names)
    right: {},          # row index => text after the frame (legend)
    bottom: nil         # [left_text, right_text] under the frame, at
                        #   its two ends (x-axis extremes)
).to_s                  # => String, "\n"-terminated, no trailing blank
Tessella::Color.wrap(text, color) # ANSI wrap; nil => text as is; a
                                  #   name, a 0..255 index (38;5) or
                                  #   "#rrggbb" (38;2); [fg, bg] sets
                                  #   the background too (a cell split
                                  #   between two series)
Tessella::Color::NAMES            # :red :green :yellow :blue :magenta
                                  #   :cyan :white, the series cycle
Tessella::Color::Gradient.at(stops, row, rows)  # row 0 the bottom:
                                  #   equal bands, or a smooth blend
                                  #   when every stop is "#rrggbb"
```

## Chart and kinds

```ruby
chart = Tessella.line(x = nil, y, name: nil, **opts)  # also scatter,
                                            #   stairs, density; name:
                                            #   names the first series
chart.add(x = nil, y, name: nil, color: nil, mark: nil) # another
                                            #   series
Tessella.stairs(x = nil, y, style: :post, **opts)  # or style: :pre,
                                            #   as unicode_plot's stairs
Tessella.line(y, area: true, gradient: %i[green yellow red]) # line,
                                            #   stairs: filled, btop-style;
                                            #   canvas: :eighths, by eighths
    # threshold: N, above:, below: (line, scatter, stairs): a dashed
    #   rule at N, cells beyond it coloured above: (kinds/threshold.rb;
    #   a canvas colour may be a callable of the cell's row and column)
    # yerr: (line, scatter): error bars along the value axis
    #   (kinds/error_bars.rb), kept apart from Series as bounds
    # x values that are times: a date axis in UTC (kinds/date_axis.rb),
    #   xdate: its strftime format; `chart --xdate` parses ISO 8601 in
    #   plain Ruby (cli/iso_time.rb), as the library requires only zlib
    # orientation: the direction the value axis runs, every kind but
    #   stem: plotted kinds :vertical by default, :horizontal swaps the
    #   axes (kinds/sideways.rb, each series stored swapped); bar,
    #   histogram, box :horizontal by default, :vertical for columns
Tessella.bar(labels, values, **opts)
Tessella.histogram(values, bins: nil, closed: :left, **opts)
    # bar, histogram: orientation: :horizontal | :vertical (columns),
    #   blocks: :eighths | :braille | :block (:quadrant) | :half
    #   (kinds/columns.rb); only
    #   horizontal :eighths is unicode_plot's layout, the oracle's;
    #   values an Array per label: several series, grouped or
    #   stacked: true, series: their names (kinds/multibar*.rb)
Tessella.heatmap(matrix, xlabels: nil, ylabels: nil, cell_width: 2,
                 colormap: nil, min: nil, max: nil, **opts)  # shaded
    # cells, a colormap under color: (kinds/heatmap.rb)
Tessella.candlestick(x = nil, open:, high:, low:, close:, **opts)
    # OHLC, a column a candle (kinds/candlestick.rb)
Tessella.pie(labels, values, donut: false, **opts)  # slices by fill,
    # a ring under donut:, no axes, so no width: (kinds/pie.rb)
Tessella.box(names, samples, **opts)        # samples: Array of Arrays;
    # orientation: :vertical stands the boxes (kinds/box_upright.rb)
Tessella.stem(values, scale: nil, **opts)   # stem-and-leaf
chart.to_s; chart.render(io = $stdout)
```

The common options, their defaults and the bar options (`fill:`,
`eighths:`, `track:`) are the README's ("The library"). `xscale:` runs
every series' x through `Stats.transform` before limits and drawing,
the same transform Stats offers for any other value.

`Tessella::Chart` is the base class every kind subclasses, so bar,
histogram, box and stem build on the same contract as line, scatter,
stairs and density do. The base provides: parsing and validating the
common options above, with their defaults; `add`'s series bookkeeping
(the default x = 1..y.length, a colour for a series that gives none,
cycling over `Color::NAMES`); choosing and building the canvas and
assembling the `Frame` around it (the y-axis extremes left via
`Axis.tick`, a legend on the right naming each series `add` gave a
name, in that order, the x extremes along the bottom); `ascii: true`
selecting the ascii canvas and frame by default; and `to_s` /
`render`. A subclass implements `draw_series(canvas, series)` -- how
one series's points reach the canvas (a line connects them; a scatter
or density does not) -- and may override `default_canvas_type`,
`canvas_type`, `default_border`, `draw_grid?` (whether the x = 0 /
y = 0 axis lines draw when in range; density's own default is off, as
unicode_plot's densityplot sets `grid: false` where lineplot and
scatterplot leave it `true`), or `add` itself, as stairs does to turn
its points into a step path before the series is stored. A series
added with `mark:` skips `draw_series`: the base writes the glyph with
`canvas.mark` at each point (stairs stores such a series unstepped),
so every grid kind marks points the same way, and a mark sits over a
line in the same chart rather than needing a chart kind of its own. Density
always draws on the `:density` canvas, ignoring any `canvas:` option,
and forwards `ascii:` to it as that canvas's own ascii sign set rather
than switching to the `:ascii` canvas type.

Box draws its own frame -- unicode_plot's corner style, open sides,
and a third bottom label (min, mean, max) that Frame's two-slot
`bottom:` cannot carry -- so it accepts `border:` and ignores it. Bar
and histogram take no series `name:` in `add`: the label on the left
already names each bar. Histogram labels are computed as Floats, so
bins of width 10 or more render.

## Command line

```ruby
Tessella::CLI.run(argv, stdin:, stdout:, stderr:)  # => exit status:
    # argv[0] names the command (CLI::COMMANDS), the rest go to it;
    # --help and --version answer 0; none or an unknown one, 2
Tessella::ChartCLI.run(argv, stdin:, stdout:, stderr:)  # `chart`:
    # 0 drawn; 1 bad input (ChartCLI::DataError); 2 usage
    # (OptionParser::ParseError, ChartCLI::UsageError, or an
    # ArgumentError from the chart itself: an unknown canvas, xscale,
    # style or closed, or a fill longer than one character)
```

`exe/tessella` is a thin wrapper: `exit Tessella::CLI.run(ARGV, stdin:
$stdin, stdout: $stdout, stderr: $stderr)` after requiring the library
relative to itself (tests call `CLI.run` in process with StringIO
instead). `tessella chart` parses argv, reads one file argument or
stdin, calls one `Tessella.<kind>` (plus `chart.add` for extra
line/scatter/stairs/density series), and prints the result -- nothing
more.

The options, the input format and the exit statuses are the README's
("The `tessella` command"); what the CLI owns beyond them is that a
kind refuses an option it does not take (a usage error naming both)
rather than ignoring it, and that a bad value for an option it does
take is left to the chart's own ArgumentError, so the library and the
command line refuse the same values with the same message.

A number keeps its kind (12 stays an Integer, 7.5 a Float), so values
print as given; histogram ignores any column after the first, bar
refuses a row past label and value rather than drop its other
columns unseen, and box names its boxes by the header or 1..n.

For line, scatter, stairs and density, a header names every series:
the `Tessella.<kind>` call names the first (its `name:`), and
`chart.add` each further one.

## Why it is shaped so

tessella rewrites [unicode_plot][up] 0.0.5, whose chart kinds and
canvases it takes over. It exists because drawing through unicode_plot
meant patching every output afterwards — colour stripped, trailing
blanks trimmed, bars redrawn, an ASCII frame rebuilt from the Unicode
one; the rewrite builds those rules in instead.

- **A rewrite, not a vendored copy.** Vendoring unicode_plot was
  rejected: its one dependency, `enumerable-statistics`, is a C
  extension compiled at install, the part most likely to break a
  checkout. Binning and percentiles are short enough to write in Ruby.
- **The oracle, not the source.** unicode_plot settles what each kind
  and canvas draws, under test, so parity is measured rather than
  claimed; copying its code would have imported its bugs along with
  its behaviour.
- **An original ASCII glyph rule.** unicode_plot's ASCII canvas is a
  hand-made lookup table; matching it exactly would mean reproducing
  the table. tessella's glyphs follow the stroke (top, middle or bottom
  row, a column, a diagonal), and a cell with at least 7 of its 9
  pixels set is `#`, checked before the crossings — any such cell holds
  a full row and a full column, so the other order makes `#`
  unreachable. It is judged by eye, not by parity.
- **Colour off by default.** The output's first use is inside a
  document, where an escape code is garbage; colour stays available as
  an option.
- **Bars configurable, with the gem's look one setting away.** The
  default is eighths on a `·` track, which shows a bar's fraction and
  its share of the width; but `fill: "■"` (`"▇"` for histograms),
  `eighths: false`, `track: nil` give unicode_plot's output byte for
  byte, which is what lets the bar kinds be tested against it.

Where tessella departs from unicode_plot, it does so on purpose:

- **Density canvas below 5 cells.** unicode_plot clamps it to 5,
  drawing a larger chart than was asked for; tessella honours the size.
- **Histogram labels on bins of width 10 or more.** unicode_plot's
  label rounding returns an Integer there and crashes; tessella
  computes labels as Floats.
- **`10`, not `10.0`, at an axis extreme.** Limits are always Floats,
  so formatting them as values printed `10.0` on every axis;
  `Axis.tick` drops a whole Float's `.0` as unicode_plot does, while
  `Axis.label` keeps a plotted value's own form.
- **Exact stem leaves.** unicode_plot truncates `value / (scale / 10)`
  as a Float, so 0.3 at scale 1 (2.9999999999999996 tenths) lands on
  leaf 2; tessella rounds to 9 decimals before truncating.
- **Constant data of 1e16 and more.** unicode_plot widens a constant
  by ±1, which a Float that large cannot hold: its axis crashes and
  its histogram bins come out empty. tessella grows the step by tens
  until it changes the value; below 1e16 the result is unicode_plot's.
- **Negative bars.** unicode_plot refuses them. tessella splits the
  bar area at a zero column so both signs draw to one scale; with no
  negative value the layout is unicode_plot's, byte for byte.
- **Refusals before drawing.** A value that is not a finite number, a
  width or height that is not a positive Integer, x and y of
  different lengths, a stem scale that is not positive, or a stem plot
  past 1000 stems raise `ArgumentError` naming them, where unicode_plot
  crashes, hangs, or draws a mistake.
- **Display width.** Labels are measured in the columns a terminal
  gives them (`Width`), so CJK labels keep the frame aligned. Its
  tables, generated from Unicode 15.1, came from the ascii-art skill's
  artlint.rb and are now the lint's own ("Lint"), so the library and
  the lint that checks its output count the same columns. The
  markdown skill's check_md.rb keeps a copy, which must stay
  identical.

The name: a tessella is one tile of a mosaic, as one character cell is
one tile of every figure here. It is free on rubygems.org with no gem
one edit or one `-`/`_` away, which rubygems.org would refuse as too
close; `ascii-art` was not (`ascii_art` exists), nor were `inkplot`
and charts-only names once the library went past charts.

[up]: https://github.com/red-data-tools/unicode_plot
