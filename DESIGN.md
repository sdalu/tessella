# inkchart — design

Charts for a monospace grid: line, scatter, stairs, bar, histogram, box,
stem and density plots, drawn in Unicode (braille, block, dot, density
canvases) or pure ASCII, with scaled axes, for documents first and
terminals second. Plain Ruby 3.4, no runtime dependency.

This note fixes the internal interfaces the parts are built against.
Each part has one owner file set; a part may rely only on what is
written here about another, so they can be built and tested apart.

## Rules that hold in every part

- **No runtime dependency.** Statistics, scaling and drawing are plain
  Ruby; the gemspec lists none. unicode_plot is a *test oracle* only
  (test/oracle.rb), and no code is copied from it.
- **Output is document-safe by construction.** No trailing blank on any
  line, no ANSI escape unless `color: true`, no tab, no invisible
  glyph; a blank cell is U+0020, never U+2800. `ascii: true` output is
  ASCII-only from the first byte: no part draws Unicode and lets a later
  pass rewrite it.
- **Values as given.** An Integer label stays an Integer (`12`, not
  `12.0`); a Float keeps its digits.
- **One file, one load order.** `lib/inkchart.rb` requires every other
  file, in dependency order, and the standard library (`optparse`, for
  the CLI) above them; no other lib file calls `require` or
  `require_relative`. `tools/bundle.rb` relies on
  that to concatenate the library into one file for vendoring.
- **House Ruby**: the ruby skill (`.rubocop.yml` is its gate, copied
  here): 4-space indent, 80 columns, methods of 10 lines or fewer,
  classes of 100 or fewer, double quotes, `it` for a single block
  parameter.

## Layout

```text
lib/inkchart.rb            the public entry: requires, Inkchart.<kind>
lib/inkchart/version.rb    VERSION, the one place it is written
lib/inkchart/error.rb      Inkchart::Error < StandardError
lib/inkchart/cell.rb       Inkchart::Cell (Data: char, color), Cell.blank
lib/inkchart/stats.rb      binning, percentiles, transforms
lib/inkchart/axis.rb       limits, nice rounding, number labels
lib/inkchart/color.rb      colour names to ANSI, and nothing else
lib/inkchart/canvas.rb     the base grid
lib/inkchart/canvas/*.rb   braille, block, dot, ascii, density
lib/inkchart/frame.rb      border, labels, title, legend, render
lib/inkchart/chart.rb      shared options, series, render entry
lib/inkchart/kinds/*.rb    one file per kind
exe/inkchart               the command line
tools/bundle.rb            single-file build for vendoring
test/                      minitest; test/oracle.rb loads unicode_plot
```

## Stats and Axis

```ruby
Inkchart::Stats.histogram(values, bins: nil, closed: :left)
    # => Inkchart::Stats::Histogram (Data: edges, counts, closed)
    #    bins: nil = the count unicode_plot picks for the same data;
    #    edges ascending, counts.size == edges.size - 1; :left means
    #    [a, b), :right (a, b]; every value lands in exactly one bin
Inkchart::Stats.percentiles(values, ps)   # ps in 0..100, linear
    # interpolation between order statistics (the definition
    # enumerable-statistics uses), => Array of Float
Inkchart::Stats.transform(name)           # :identity :ln :log2 :log10
    # => a callable; nil and :identity are the identity
Inkchart::Axis.limits(values, lim = nil)  # => [lo, hi]
    # lim [a, b] given and not [0, 0]: returned as is; otherwise the
    # data's extent widened to round values exactly as unicode_plot
    # widens it (its axis labels are the oracle)
Inkchart::Axis.label(number)              # => String for a value
    # label (a bar's value): Integer as is; Float in the shortest form
    # that round-trips, no exponent for |x| in 1e-4...1e15
Inkchart::Axis.tick(number)               # => String for an axis
    # extreme: as label, but a whole Float drops its ".0" (limits are
    # always Floats; 10 not 10.0, as unicode_plot prints them)
```

## Canvas

A grid of character cells, each cell a block of pixels; data coordinates
map onto pixels, pixel (0, 0) is the bottom-left.

```ruby
Inkchart::Canvas.build(type, width:, height:, xlim:, ylim:)
    # type :braille (2x4 px per cell), :block (2x2), :dot (1x2),
    # :ascii (3x3), :density (1x2, glyph by hit count)
canvas.width, canvas.height              # cells
canvas.pixel_width, canvas.pixel_height
canvas.point(x, y, color: nil)           # data coordinates; outside
canvas.line(x0, y0, x1, y1, color: nil)  #   the limits: clipped
canvas.points(xs, ys, color: nil)
canvas.lines(xs, ys, color: nil)         # joins consecutive points
canvas.rows                              # => Array (top row first) of
    # Array of Inkchart::Cell (Data: char, color); char " " is blank
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
Inkchart::Frame.new(
    body:,              # Array of rows of Inkchart::Cell, equal width
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
Inkchart::Color.wrap(text, name)  # ANSI wrap; name nil => text as is
Inkchart::Color::NAMES            # :red :green :yellow :blue :magenta
                                  #   :cyan :white, the series cycle
```

## Chart and kinds

```ruby
chart = Inkchart.line(x = nil, y, name: nil, **opts)  # also scatter,
                                            #   stairs, density; name:
                                            #   names the first series
chart.add(x = nil, y, name: nil, color: nil, mark: nil) # another
                                            #   series
Inkchart.stairs(x = nil, y, style: :post, **opts)  # or style: :pre,
                                            #   as unicode_plot's stairs
Inkchart.bar(labels, values, **opts)
Inkchart.histogram(values, bins: nil, closed: :left, **opts)
Inkchart.box(names, samples, **opts)        # samples: Array of Arrays
Inkchart.stem(values, scale: nil, **opts)   # stem-and-leaf
chart.to_s; chart.render(io = $stdout)
```

The common options, their defaults and the bar options (`fill:`,
`eighths:`, `track:`) are the README's ("The library"). `xscale:` runs
every series' x through `Stats.transform` before limits and drawing,
the same transform Stats offers for any other value.

`Inkchart::Chart` is the base class every kind subclasses, so bar,
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
Inkchart::CLI.run(argv, stdin:, stdout:, stderr:)  # => exit status:
    # 0 drawn; 1 bad input (Inkchart::CLI::DataError); 2 usage
    # (OptionParser::ParseError, Inkchart::CLI::UsageError, or an
    # ArgumentError from the chart itself: an unknown canvas, xscale,
    # style or closed, or a fill longer than one character)
```

`exe/inkchart` is a thin wrapper: `exit Inkchart::CLI.run(ARGV, stdin:
$stdin, stdout: $stdout, stderr: $stderr)` after requiring the library
relative to itself (tests call `CLI.run` in process with StringIO
instead). It parses argv, reads one file argument or stdin, calls one
`Inkchart.<kind>` (plus `chart.add` for extra line/scatter/stairs/
density series), and prints the result -- nothing more.

The options, the input format and the exit statuses are the README's
("The `inkchart` command"); what the CLI owns beyond them is that a
kind refuses an option it does not take (a usage error naming both)
rather than ignoring it, and that a bad value for an option it does
take is left to the chart's own ArgumentError, so the library and the
command line refuse the same values with the same message.

A number keeps its kind (12 stays an Integer, 7.5 a Float), so values
print as given; histogram ignores any column after the first, and box
names its boxes by the header or 1..n.

For line, scatter, stairs and density, a header names every series:
the `Inkchart.<kind>` call names the first (its `name:`), and
`chart.add` each further one.

## Why it is shaped so

inkchart rewrites [unicode_plot][up] 0.0.5, whose chart kinds and
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
  the table. inkchart's glyphs follow the stroke (top, middle or bottom
  row, a column, a diagonal), and a cell with at least 7 of its 9
  pixels set is `#`, checked before the crossings — any such cell holds
  a full row and a full column, so the other order makes `#`
  unreachable. It is judged by eye, not by parity.
- **Colour off by default.** The output's first use is inside a
  document, where an escape code is garbage; colour stays available as
  an option.
- **Bars configurable, with the gem's look one setting away.** The
  default is eighths on a `·` track, which shows a bar's fraction and
  its share of the width; but `fill: "■"` (`"▇"` for histograms), `eighths: false`,
  `track: nil` give unicode_plot's output byte for byte, which is what
  lets the bar kinds be tested against it.

Where inkchart departs from unicode_plot, it does so on purpose:

- **Density canvas below 5 cells.** unicode_plot clamps it to 5,
  drawing a larger chart than was asked for; inkchart honours the size.
- **Histogram labels on bins of width 10 or more.** unicode_plot's
  label rounding returns an Integer there and crashes; inkchart
  computes labels as Floats.
- **`10`, not `10.0`, at an axis extreme.** Limits are always Floats,
  so formatting them as values printed `10.0` on every axis;
  `Axis.tick` drops a whole Float's `.0` as unicode_plot does, while
  `Axis.label` keeps a plotted value's own form.

The name: `inkplot` was the first choice and is taken on rubygems.org
by an unrelated gem.

[up]: https://github.com/red-data-tools/unicode_plot
