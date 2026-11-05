# Charts

A chart turns numbers into a framed figure: a plot area of character
cells, the y extremes on its left, the x extremes under it, a title
above and a legend on the right. There are eleven kinds:

| Kind        | Draws                                      | Input           |
|-------------|--------------------------------------------|-----------------|
| `line`      | points joined by straight segments         | y, or x and y   |
| `scatter`   | points, not joined                         | y, or x and y   |
| `stairs`    | a step path between points                 | y, or x and y   |
| `density`   | points, shaded by how many share a cell    | y, or x and y   |
| `bar`       | one horizontal bar per label               | labels, values  |
| `histogram` | counts of samples per bin, as bars         | samples         |
| `box`       | a box-and-whisker plot per sample set      | sets of samples |
| `stem`      | a stem-and-leaf plot, as text              | values          |
| `heatmap`   | a matrix as a grid of shaded cells         | rows of values  |
| `candlestick` | open, high, low, close per x, as candles | x, four prices  |
| `pie`       | shares of a whole, as a disc or a ring     | labels, values  |

Every example on this page is the command's output, byte for byte;
the input files are in [examples/](../examples/), and every command
runs there.

## From the command line

`tessella chart` reads one file, or stdin when no file is given, and
prints one chart. `--kind` picks the kind; `line` is the default.

```text
$ tessella chart --title trig --width 30 --height 6 trig.txt
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

`trig.txt` is a header row `x sin cos` and 101 rows of numbers. The
first column is x; each further column is one series, named by the
header.

### The input format

- A line holding a comma splits on commas, one holding a tab on
  tabs, any other on runs of spaces. A CSV or TSV label may therefore
  hold spaces.
- Blank lines and lines starting with `#` are skipped.
- A first row that is not all numbers is a header: it names the
  series (line, scatter, stairs, density), the boxes (box) or the two
  sides (back-to-back stem). For `bar`, the first row is a header
  when its value field is not a number.
- A number keeps its kind: `12` stays an Integer and prints `12`,
  `7.5` stays a Float.

What each kind reads:

| Kind                                  | Columns                                                         |
|---------------------------------------|-----------------------------------------------------------------|
| `line`, `scatter`, `stairs`, `density` | one column: y against 1..n; two: x y; more: x, then one series each |
| `bar`                                 | label, value; or label and one value per series                 |
| `histogram`                           | one column of samples (further columns are ignored)             |
| `box`                                 | one or more columns, one box per column                         |
| `stem`                                | one column; two for the back-to-back form                       |
| `heatmap`                             | a label, then the row's values; a header names the columns      |
| `candlestick`                         | x, open, high, low, close                                       |
| `pie`                                 | label, value                                                    |

## The kinds

### line, scatter, stairs

`line` joins consecutive points; `scatter` draws them alone; `stairs`
draws a step path. Each series gets the next colour of the cycle
(used only under `--color`) and, when it has a name, a legend entry.

```text
$ tessella chart --kind scatter --width 30 --height 6 trig.txt
      ┌──────────────────────────────┐
    1 │⠉⠱⡤⠊⠉⠉⢢⡀        ⢠⠊⠉⠉⠢⡴⠊⠉⠙⢢    │ sin
      │ ⡰⠉⢆   ⠘⡄      ⡰⠁   ⡔⠙⢄   ⠑⡀  │ cos
      │⠜  ⠈⢂   ⠐⡄    ⠔⠁  ⢀⠜  ⠈⡄   ⠱⡀ │
      │⠉⠉⠉⠉⠉⢏⠉⠉⠉⠙⡉⠉⠉⡹⠉⠉⠉⠉⡍⠉⠉⠉⠉⠉⠏⠉⠉⠉⠩⡉│
      │      ⢅   ⠘⡄⡜   ⢀⠎      ⠘⢄   ⠱│
   -1 │       ⠱⣄⣀⣠⠎⠢⣀⣀⡰⠊        ⠈⠣⣄⣀⡠│
      └──────────────────────────────┘
      0                             10
```

`stairs` steps after each point by default (`--style post`); `--style
pre` steps before it:

```text
$ printf '1 1\n2 3\n3 2\n4 4\n' | \
    tessella chart --kind stairs --style pre --width 20 --height 4
     ┌────────────────────┐
   4 │             ⡏⠉⠉⠉⠉⠉⠉│
     │⡖⠒⠒⠒⠒⠒⢲      ⡇      │
     │⡇     ⠸⠤⠤⠤⠤⠤⠤⠇      │
   1 │⡇                   │
     └────────────────────┘
     1                    4
```

### Filled areas

`--area` (`area: true`) fills under each line or stairs series, from
the floor up, as btop draws its graphs. Every pixel column is a bar
of its own, so a braille cell holds two bars of 0 to 4 dots, and a
peak narrower than a cell still shows. The y axis starts at 0 unless
`--ylim` says otherwise. `cpu.txt` is 60 load samples between 10 and
90:

```text
$ tessella chart --area --width 30 --height 6 cpu.txt
      ┌──────────────────────────────┐
   90 │  ⢀⣴⣾⣿⣷⣄             ⢀⣴⣿⣿⣶⣄   │
      │ ⢠⣾⣿⣿⣿⣿⣿⣧⡀          ⣠⣿⣿⣿⣿⣿⣿⣦  │
      │⢠⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀        ⣰⣿⣿⣿⣿⣿⣿⣿⣿⣧⡀│
      │⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡄      ⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷│
      │⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄   ⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿│
    0 │⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿│
      └──────────────────────────────┘
      0                             60
```

On the block canvas a cell holds two bars of 0 to 2; under `--ascii`
the fill is drawn in ASCII strokes:

```text
$ tessella chart --area --canvas block --width 30 --height 6 cpu.txt
      ┌──────────────────────────────┐
   90 │   ▄██▙▄              ▟██▙▖   │
      │ ▗██████▙           ▗██████▙  │
      │▗████████▙▖        ▗████████▙ │
      │▐██████████▖      ▟██████████▙│
      │▐███████████▄   ▗▟████████████│
    0 │▐█████████████▄▟██████████████│
      └──────────────────────────────┘
      0                             60
```

```text
$ tessella chart --area --ascii --width 30 --height 6 cpu.txt
      +------------------------------+
   90 |  .+###-             .+###_   |
      | _######+           -######-  |
      |-########+.        -########+ |
      |+##########.      +##########+|
      |+###########-   .#############|
    0 |+#############-###############|
      +------------------------------+
      0                             60
```

With `--ylim` the floor moves up, so the variation fills the height:

```text
$ tessella chart --area --ylim 30,100 --width 30 --height 4 cpu.txt
       ┌──────────────────────────────┐
   100 │   ⢀⣠⣤⣀               ⢀⣠⣤⣀    │
       │  ⣴⣿⣿⣿⣿⣷⣄           ⢀⣴⣿⣿⣿⣿⣷⡄  │
       │⢀⣾⣿⣿⣿⣿⣿⣿⣿⣦         ⢠⣾⣿⣿⣿⣿⣿⣿⣿⣆ │
    30 │⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀      ⣰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧│
       └──────────────────────────────┘
       0                             60
```

Under `--color` a filled cell is coloured by its height, bottom row
first, from a gradient: `--gradient C,C,...` (`gradient: [...]`), by
default green, yellow, red in equal bands. A gradient whose colours
are all `#rrggbb` blends smoothly from the bottom row to the top
instead of in bands. `--gradient none` (`gradient: false`) keeps the
series' own colour. Without `--color` a gradient changes nothing and
the glyphs are plain.

`--area` is for line and stairs only, and `--gradient` needs
`--area`; anything else is a usage error:

```text
$ tessella chart --gradient red,blue cpu.txt
tessella chart: gradient: needs area: true
Usage: tessella chart [options] [file]
```

### density

`density` draws the points on its own canvas, where a cell's shade
grows with the number of points that fall in it (` ░▒▓█`, or `
.:+#` under `--ascii`). It ignores `--canvas`, and draws no x = 0
or y = 0 axis line.

```text
$ tessella chart --kind density --width 30 --height 6 trig.txt
      ┌──────────────────────────────┐
    1 │▓▒▓▓▒▒▓░        ▒▒▓▒▒█▒▒▓▒    │ sin
      │ ▒▒▒   ▒▒      ▒░   ▒▒▒   ▒░  │ cos
      │▒  ░▒   ░▒    ▒░  ░▒  ░▒   ▒░ │
      │░   ░▒   ▒░  ▒░   ▒    ░▒   ▒░│
      │      ▓   ▒▒▓   ░▒      ▒▒   ▒│
   -1 │       ▒▒▓▒▓▓▒▒▓▒        ░▒▓▒▓│
      └──────────────────────────────┘
      0                             10
```

### bar

One bar per row, labelled on the left, with its value after it.

```text
$ tessella chart --kind bar --width 30 langs.csv
        ┌                              ┐
   ruby ┤██████████▍··············· 12
      c ┤██████████████████████████ 30
   rust ┤██████▌··················· 7.5
        └                              ┘
```

The default look draws the last, fractional cell in eighths
(`▏▎▍▌▋▊▉`) and fills the rest of each bar's width with a `·` track,
so a bar shows both its fraction and its share. Three options change
it: `--fill G` the bar glyph, `--no-eighths` whole cells only, and
`--track G` the track glyph (`--track none` for no track):

```text
$ tessella chart --kind bar --width 30 \
    --fill ■ --no-eighths --track none langs.csv
        ┌                              ┐
   ruby ┤■■■■■■■■■■ 12
      c ┤■■■■■■■■■■■■■■■■■■■■■■■■■■ 30
   rust ┤■■■■■■■ 7.5
        └                              ┘
```

Values may be negative. The bar area then splits at a zero column,
each side as wide as its share of the values' span; negative bars
grow left, and a negative bar's fractional end is a half cell (`▐`):

```text
$ tessella chart --kind bar --width 30 neg.csv
     ┌                              ┐
   a ┤█████████████████········· -6
   b ┤·················█████████ 3
   c ┤·························· 0
     └                              ┘
```

#### Several series

A row with more than one value draws one bar per series; the header
names the series, and a legend right of the frame shows each one's
fill. `hosts.csv` holds a load per host for three resources:

```text
$ cat hosts.csv
host,cpu,io,net
web,40,15,20
db,25,50,5
cache,10,5,30
```

By default the bars are grouped: each label gets one bar per series,
with a blank row between labels.

```text
$ tessella chart --kind bar --width 30 hosts.csv
         ┌                              ┐
     web ┤████████████████████▊····· 40  █ cpu
         ┤▓▓▓▓▓▓▓▓·················· 15  ▓ io
         ┤▒▒▒▒▒▒▒▒▒▒················ 20  ▒ net
         ┤
      db ┤█████████████············· 25
         ┤▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 50
         ┤▒▒▒······················· 5
         ┤
   cache ┤█████▎···················· 10
         ┤▓▓▓······················· 5
         ┤▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒·········· 30
         └                              ┘
```

`--stacked` (`stacked: true`) sets them end to end in one bar, its
total as the label:

```text
$ tessella chart --kind bar --stacked --width 30 hosts.csv
         ┌                              ┐
     web ┤█████████████▓▓▓▓▓▒▒▒▒▒▒·· 75  █ cpu
      db ┤████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒ 80  ▓ io
   cache ┤███▓▓▒▒▒▒▒▒▒▒▒▒··········· 45  ▒ net
         └                              ┘
```

Both stand upright with `--orientation vertical`:

```text
$ tessella chart --kind bar --stacked --orientation vertical \
    --width 20 --height 6 hosts.csv
      ┌────────────────────┐
   80 │▒▒▒▒▒▒ ▓▓▓▓▓▓       │ █ cpu
      │▒▒▒▒▒▒ ▓▓▓▓▓▓       │ ▓ io
      │▓▓▓▓▓▓ ▓▓▓▓▓▓       │ ▒ net
      │██████ ▓▓▓▓▓▓ ▒▒▒▒▒▒│
      │██████ ██████ ▒▒▒▒▒▒│
    0 │██████ ██████ ██████│
      └────────────────────┘
         web    db    cache
```

With more series than labels the legend no longer fits beside the
bars, so it goes under the frame, wrapped to the plot's width (for
upright columns,
whose names take that line, on the x-label line, unless `--xlabel`
is given). Here the first two hosts only:

```text
$ head -3 hosts.csv | tessella chart --kind bar --stacked --width 30
       ┌                              ┐
   web ┤█████████████▓▓▓▓▓▒▒▒▒▒▒·· 75
    db ┤████████▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒ 80
       └                              ┘
        █ cpu  ▓ io  ▒ net
```

Each series has a fill of its own, from twelve: `█ ▓ ▒ ░ ╳ ╱ ╲ ∴ ● ○
◆ ·`, or `# = + @ * : . o % & ~ x` under `--ascii`. So a chart holds
at most 12 series; a 13th is refused. Only a `█` series ends in an
eighth. Bars of several series need values of 0 or more.

```text
$ tessella chart --kind bar --stacked --ascii --width 30 hosts.csv
         +                              +
     web |#############=====++++++.. 75  # cpu
      db |########================++ 80  = io
   cache |###==++++++++++........... 45  + net
         +                              +
```

In Ruby, the values are an Array of Arrays, one per label, and
`series:` names them:

```ruby
Tessella.bar(%w[web db cache], [[40, 15, 20], [25, 50, 5], [10, 5, 30]],
             series: %w[cpu io net], stacked: true, width: 30)
```

### histogram

`histogram` bins one column of samples and draws the counts as bars,
with the same bar options. `--bins N` sets the number of bins (by
default Sturges' rule, ⌈log₂ n⌉ + 1, as unicode_plot picks it);
`--closed left` (the default) bins as `[a, b)`, `--closed right` as
`(a, b]`. Every sample lands in exactly one bin.

```text
$ tessella chart --kind histogram --width 30 --bins 8 normal.txt
                ┌                              ┐
   [-3.0, -2.0) ┤██▉······················· 8
   [-2.0, -1.0) ┤██████████▏··············· 28
   [-1.0,  0.0) ┤██████████████████████████ 72
   [ 0.0,  1.0) ┤██████████████████████···· 61
   [ 1.0,  2.0) ┤██████████▏··············· 28
   [ 2.0,  3.0) ┤█▏························ 3
                └                              ┘
                           Frequency
```

`--bins` is a request: the edges are rounded to nice values, which
can give fewer bins than asked, as here.

### box

One box per column: whiskers from minimum to maximum, the box from
the first to the third quartile, the median inside it. The axis under
the boxes shows the minimum, the middle and the maximum of the range.

```text
$ tessella chart --kind box --width 40 samples.txt
     ┌                                        ┐
      ╷ ┬─┐ ╷
   a  ├─│ ├─┤
      ╵ ┴─┘ ╵
        ╷┌┬┐     ╷
   b    ├┤│├─────┤
        ╵└┴┘     ╵
         ╷  ┌┬┐                              ╷
   c     ├──┤│├──────────────────────────────┤
         ╵  └┴┘                              ╵
     └                                        ┘
     0                  15                   30
```

The box draws its own open frame; it takes no `border:`.

### stem

A stem-and-leaf plot is text, not a canvas: one line per stem, its
leaves after the bar, and a key under it. `--scale N` sets what one
stem step is worth (10 by default): at scale 10, `2 | 37` reads 23
and 27.

```text
$ tessella chart --kind stem stem.txt
1 | 25
2 | 1337
3 | 148
4 | 57
5 | 2
Key: 1|0 = 10
The decimal is 1 digit(s) to the right of |
```

Two columns give the back-to-back form, the first column's leaves
read leftwards:

```text
$ tessella chart --kind stem ages.txt
 52 | 1 | 8
731 | 2 | 25
 84 | 3 | 136
  5 | 4 | 14
Key: 1|0 = 10
The decimal is 1 digit(s) to the right of |
```

A plot that would need more than 1000 stems is refused: raise
`--scale`.

### heatmap

A heatmap draws a matrix as a grid of cells, each shaded by its value
along ` ░▒▓█`, with the row names on the left and a key on the right
giving the range. `week.txt` is a load per day and per three hours.
Its first row names the columns because `0h`, `3h` are not numbers;
a header of `00 03 06` would be read as a row of data, by the rule of
[the input format](#the-input-format):

```text
$ head -3 week.txt
day 0h 3h 6h 9h 12h 15h 18h 21h
mon 10 14 18 72 76 63 67 21
tue 23 10 14 68 72 76 63 17
```

```text
$ tessella chart --kind heatmap week.txt
       ┌────────────────┐
   mon │░░░░░░████▓▓██░░│ █ 76
   tue │░░░░░░██████▓▓░░│
   wed │░░░░░░▓▓██████░░│
   thu │░░░░░░▓▓▓▓████░░│
   fri │░░░░░░██▓▓▓▓██░░│
   sat │      ▒▒▒▒▒▒▒▒  │
   sun │      ▒▒▒▒▒▒▒▒  │   0
       └────────────────┘
       0h             21h
```

A cell is `--cell-width` columns wide, 2 by default (near square in a
terminal). The column names go under the frame when each is narrower
than a cell, else only the first and last, at the two ends, as in
the map above. At four columns a cell, every name fits:

```text
$ tessella chart --kind heatmap --cell-width 4 week.txt
       ┌────────────────────────────────┐
   mon │░░░░░░░░░░░░████████▓▓▓▓████░░░░│ █ 76
   tue │░░░░░░░░░░░░████████████▓▓▓▓░░░░│
   wed │░░░░░░░░░░░░▓▓▓▓████████████░░░░│
   thu │░░░░░░░░░░░░▓▓▓▓▓▓▓▓████████░░░░│
   fri │░░░░░░░░░░░░████▓▓▓▓▓▓▓▓████░░░░│
   sat │            ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒    │
   sun │            ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒    │   0
       └────────────────────────────────┘
         0h  3h  6h  9h 12h 15h 18h 21h
```

Under `--ascii` the ramp is ` .:-=+*#%@`. Under `--color` each cell is
a `█` coloured along a colormap, a viridis-like blend by default, or
`--colormap C,C,...` stops in any [colour form](#colour); the key then
says "max" and "min" in words. `--min` and `--max` fix the range, so
maps drawn apart share one scale. A map of one row gives its key as
`lo..hi`:

```text
$ printf 'x 1 2 3 4\n' | tessella chart --kind heatmap
     ┌────────┐
   x │  ░░▓▓██│ 1..4
     └────────┘
```

The matrix sets the size, so `--width` and `--height` are refused. In
Ruby:

```ruby
Tessella.heatmap(matrix, xlabels: nil, ylabels: nil, cell_width: 2,
                 colormap: nil, min: nil, max: nil, **opts)
```

### candlestick

A candlestick chart draws, per x, the range a price moved in (the
wick, `│`, from low to high) and where it opened and closed (the
body). An up candle, closing at or above its open, is `█`; a down
one `▒`; one that closes where it opened, `─`. Under `--color` up is
green and down red. `ohlc.txt` is a week of prices, x as ISO dates:

```text
$ cat ohlc.txt
date open high low close
2026-11-02 100 104 98 103
2026-11-03 103 107 101 102
2026-11-04 102 103 95 96
2026-11-05 96 99 94 98
2026-11-06 98 105 97 104
2026-11-09 104 106 102 104
```

```text
$ tessella chart --kind candlestick --xdate --width 30 --height 8 ohlc.txt
       ┌─────────────────────────────┐
   110 │                             │
       │      │                   │  │
       │████ ▒▒▒▒  │        ████ ────│
       │████ ▒▒▒▒ ▒▒▒▒      ████  │  │
       │████      ▒▒▒▒ ████ ████     │
       │          ▒▒▒▒ ████  │       │
       │                │            │
    90 │                             │
       └─────────────────────────────┘
       2026-11-02           2026-11-09
```

The candles share the width, each as wide as its share allows with a
blank column between (one column each and no gap when they do not
fit), the wick in the middle column. The first and last x go under
the frame, as dates with `--xdate` (formatted as on a
[date axis](#dates-on-the-x-axis)). Under `--ascii` an up candle is
`#`, a down one `=`:

```text
$ tessella chart --kind candlestick --xdate --ascii \
    --width 30 --height 8 ohlc.txt
       +-----------------------------+
   110 |                             |
       |      |                   |  |
       |#### ====  |        #### ----|
       |#### ==== ====      ####  |  |
       |####      ==== #### ####     |
       |          ==== ####  |       |
       |                |            |
    90 |                             |
       +-----------------------------+
       2026-11-02           2026-11-09
```

A low above the open or the close, or a high below them, is refused.
In Ruby:

```ruby
Tessella.candlestick(x, open:, high:, low:, close:, **opts)
```

### pie

A pie draws each value as a slice of a disc, clockwise from the top,
with a legend giving each label's share in whole percents that add
up to 100. It has no frame and no axes.

```text
$ tessella chart --kind pie langs.csv
           ▒▒▒▒▒█████
        ▒▒▒▒▒▒▒▒████████
      ▒▒▒▒▒▒▒▒▒▒██████████
     ▓▓▓▓▒▒▒▒▒▒▒███████████
    ▓▓▓▓▓▓▓▓▒▒▒▒████████████ █ ruby 24 %
    ▓▓▓▓▓▓▓▓▓▓▓▒████████████ ▓ c 61 %
    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ ▒ rust 15 %
    ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
     ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
           ▓▓▓▓▓▓▓▓▓▓
```

`--donut` (`donut: true`) cuts out the middle:

```text
$ tessella chart --kind pie --donut langs.csv
           ▒▒▒▒▒█████
        ▒▒▒▒▒▒▒▒████████
      ▒▒▒▒▒▒▒▒▒▒██████████
     ▓▓▓▓▒▒▒▒      ████████
    ▓▓▓▓▓▓▓          ███████ █ ruby 24 %
    ▓▓▓▓▓▓            ██████ ▓ c 61 %
    ▓▓▓▓▓▓            ▓▓▓▓▓▓ ▒ rust 15 %
    ▓▓▓▓▓▓▓          ▓▓▓▓▓▓▓
     ▓▓▓▓▓▓▓▓      ▓▓▓▓▓▓▓▓
      ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
        ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
           ▓▓▓▓▓▓▓▓▓▓
```

Each slice has a fill of its own, the twelve bars use (`█ ▓ ▒ ░ ╳ ╱
╲ ∴ ● ○ ◆ ·`, or `# = + @ * : . o % & ~ x` under `--ascii`), and a
colour under `--color`; a 13th slice is refused. `--height` sizes
the disc, 12 rows by default; its width follows, a cell being about
twice as tall as wide. With more slices than the disc has rows, the
legend goes under it, wrapped to the disc's width or 40 columns,
whichever is wider. `os.csv` has nine slices:

```text
$ tessella chart --kind pie --height 6 os.csv
       ╳╱∴███
     ░░░╳╲█████
    ▒▒▒░░╳██████
    ▒▒▒▒▒▓▓█████
     ▒▒▓▓▓▓▓███
       ▓▓▓▓▓▓
    █ linux 41 %  ▓ macos 22 %
    ▒ windows 18 %  ░ freebsd 9 %
    ╳ openbsd 4 %  ╱ netbsd 2 %  ╲ haiku 2 %
    ∴ plan9 1 %  ● qnx 1 %
```

```text
$ tessella chart --kind pie --ascii --height 8 langs.csv
        ++++####
      ++++++######
     ===++++#######  # ruby 24 %
    =======+######## = c 61 %
    ================ + rust 15 %
     ==============
      ============
        ========
```

A pie takes no `--width`, `--xlim`, `--ylim`, `--canvas` or
`--xscale` (usage errors, exit 2), and reads exactly a label and a
value a row:

```text
$ tessella chart --kind pie hosts.csv
tessella chart: row 1 has 4 columns: pie reads label value
```

In Ruby:

```ruby
Tessella.pie(labels, values, donut: false, **opts)
```

## Orientation

`--orientation horizontal|vertical` (`orientation:`) is the direction
the value axis runs. Every kind but stem takes it; bar, histogram and
box are horizontal by default, the plotted kinds vertical.

### Upright bars

`--orientation vertical` draws a bar chart as columns rising from a
floor, the value axis on the left from 0 to the largest value. The
names go under their columns when each fits, else the first and last
name go at the two ends:

```text
$ tessella chart --kind bar --orientation vertical --width 20 --height 5 \
    langs.csv
      ┌────────────────────┐
   30 │       ██████       │
      │       ██████       │
      │       ██████       │
      │██████ ██████ ▂▂▂▂▂▂│
    0 │██████ ██████ ██████│
      └────────────────────┘
        ruby     c    rust
```

A histogram stands its bins up the same way, with its axis's two ends
under them:

```text
$ tessella chart --kind histogram --orientation vertical \
    --width 24 --height 6 normal.txt
                ┌───────────────────────┐
             72 │        ███ ▁▁▁        │
                │        ███ ███        │
   Frequency    │        ███ ███        │
                │    ▃▃▃ ███ ███ ▃▃▃    │
                │    ███ ███ ███ ███    │
              0 │▅▅▅ ███ ███ ███ ███ ▂▂▂│
                └───────────────────────┘
                -3.0                  3.0
```

Upright bars need values of 0 or more. `--fill` sets the glyph of
their full cells; `--track` is for bars across only, and is refused
here. A value above 0 always draws at least one step, so a bin that
holds anything never looks empty, even in ASCII, where a step is a
whole row:

```text
$ tessella chart --kind histogram --orientation vertical --ascii \
    --width 18 --height 4 normal.txt
                +-----------------+
             72 |      ##         |
   Frequency    |      ## ##      |
                |   ## ## ## ##   |
              0 |## ## ## ## ## ##|
                +-----------------+
                -3.0            3.0
```

```text
$ tessella chart --kind bar --orientation vertical neg.csv
tessella chart: a vertical eighths bar chart needs values of 0 or more
Usage: tessella chart [options] [file]
```

### Upright boxes

A vertical box stands three columns wide, its whiskers running up and
down: `╶┬╴` at the maximum, `┌┴┐` at the third quartile, `├─┤` at the
median, `└┬┘` at the first quartile, `╶┴╴` at the minimum. The value
axis on the left shows its two ends and middle (`--ylim` sets the
range), the names go under the boxes, and where the median shares a
row with an edge of the box, the median is drawn.

```text
$ tessella chart --kind box --orientation vertical --height 10 samples.txt
      ┌────────────┐
   30 │        ╶┬╴ │
      │         │  │
      │         │  │
      │         │  │
   15 │         │  │
      │         │  │
      │    ╶┬╴  │  │
      │     │  ├─┤ │
      │├─┤ ├─┤ ╶┴╴ │
    0 │╶┴╴         │
      └────────────┘
        a   b   c
```

### Sideways plots

For line, scatter, stairs and density, `--orientation horizontal`
swaps the axes: values run along the horizontal axis and x runs up,
so a horizontal chart of (x, y) is the vertical chart of (y, x).
`--xlim`, `--ylim`, `--xlabel` and `--ylabel` keep their meaning and
move with their axis; an area fills from the left edge, its gradient
running left to right.

```text
$ tessella chart --orientation horizontal --area --width 24 --height 8 cpu.txt
      ┌────────────────────────┐
   60 │⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣶⣶⣶⣦⣤⣤⣄⣀⣀⣀   │
      │⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡶│
      │⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠿⠿⠟⠛⠛⠋⠉⠁ │
      │⣿⣿⣿⠿⠟⠛⠛⠉⠉⠉⠁             │
      │⣿⣿⣷⣦⣤⣄⣀⣀                │
      │⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣶⣶⣶⣤⣤⣤⣀⣀    │
      │⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⡦│
    0 │⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠿⠿⠛⠛⠛⠉⠉⠁ │
      └────────────────────────┘
      0                       90
```

## Bar glyphs

`--blocks` (`blocks:`) picks the glyphs bars and histograms are built
of:

| Blocks    | Upright                            | Across                             |
|-----------|------------------------------------|------------------------------------|
| `eighths` | `▁`…`█`, 8 steps a cell (default)  | `▏`…`█`, 8 steps a cell (default)  |
| `half`    | `▄` `█`, one bar a column          | `▌` `█`, one bar a row             |
| `block`   | quadrants, two bars a column       | quadrants, two bars a row          |
| `braille` | dots, two bars a column            | dots, four bars a row              |

`quadrant` is another name for `block`. The finer glyphs pack more
bars into the same width; across, a row that holds several bars is
named by its first and last, `ruby..c`:

```text
$ tessella chart --kind bar --orientation vertical --blocks braille \
    --width 20 --height 5 langs.csv
      ┌────────────────────┐
   30 │      ⢸⣿⣿⣿⣿⣿⡇       │
      │      ⢸⣿⣿⣿⣿⣿⡇       │
      │      ⢸⣿⣿⣿⣿⣿⡇       │
      │⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⡇⣀⣀⣀⣀⣀⣀ │
    0 │⣿⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⡇⣿⣿⣿⣿⣿⣿ │
      └────────────────────┘
      ruby              rust
```

```text
$ tessella chart --kind bar --blocks block --width 30 langs.csv
           ┌──────────────────────────────┐
   ruby..c │████████████▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄│
      rust │▀▀▀▀▀▀▀▘                      │
           └──────────────────────────────┘
           0                             30
```

```text
$ tessella chart --kind histogram --blocks half --width 24 normal.txt
              ┌────────────────────────┐
   -3.0..-2.0 │██▌                     │
   -2.0..-1.0 │█████████▌              │
    -1.0..0.0 │████████████████████████│
     0.0..1.0 │████████████████████▌   │
     1.0..2.0 │█████████▌              │
     2.0..3.0 │█                       │
              └────────────────────────┘
              0                       72
                      Frequency
```

Every glyph set but the default `eighths` needs values of 0 or more,
and `braille` and `block` take no `--ascii`, `--fill`,
`--no-eighths` or `--track`. As upright, a value above 0 draws at
least one step (a dot, a quadrant, a half cell); only the default
eighths bars across round as unicode_plot does, so a small value can
draw nothing there.

A refused combination is a usage error:

```text
$ tessella chart --kind bar --blocks braille --ascii langs.csv
tessella chart: blocks: braille conflicts with ascii: true
Usage: tessella chart [options] [file]
```

## Canvases

The line, scatter and stairs kinds draw on a canvas, a grid of cells
each holding a few pixels. `--canvas` picks it:

| Canvas    | Pixels per cell | Glyphs                       |
|-----------|-----------------|------------------------------|
| `braille` | 2 × 4           | braille patterns (default)   |
| `block`   | 2 × 2           | quadrant blocks `▘▝▀▖▌▞▛…` (also named `quadrant`) |
| `half`    | 1 × 2           | half blocks `▀ ▄ █`          |
| `dot`     | 1 × 2           | `'` `.` `:`                  |
| `ascii`   | 3 × 3           | ASCII strokes `- \| / \ "`…  |
| `density` | 1 × 2           | shades by hit count          |

Braille gives the finest line, ASCII survives any font:

```text
$ tessella chart --canvas block --width 24 --height 5 trig.txt
      ┌────────────────────────┐
    1 │▀▚▛▀▀▚      ▗▞▀▀▜▞▀▀▙   │ sin
      │▗▘▜▖  ▚     ▛  ▗▀▝▖  ▜▖ │ cos
      │▙▄▄█▄▄▄▙▄▄▄▟▄▄▄▙▄▄█▄▄▄█▄│
      │    ▜▖  ▚▗▞  ▗▘    ▜▖  ▜│
   -1 │     ▝▄▄▄▜▄▄▟▘      ▀▄▄▄│
      └────────────────────────┘
      0                       10
```

<!-- tessella: allow-mixed -->
```text
$ tessella chart --canvas ascii --width 24 --height 5 trig.txt
      ┌────────────────────────┐
    1 │"\/""\      ./""\/""\   │ sin
      │|"-.  \     /  _--|  \. │ cos
      │------------------------│
      │    -.  \./  |-    -.  \│
   -1 │     --_--__-"      -\__│
      └────────────────────────┘
      0                       10
```

A blank cell is always a space (U+0020), never the empty braille
pattern U+2800, which some fonts draw as dots and which is not
whitespace to a text tool.

## Common options

| CLI                 | Library               | Default                        |
|---------------------|-----------------------|--------------------------------|
| `--width N`         | `width: N`            | 40 (plot area, in cells)       |
| `--height N`        | `height: N`           | 15 (plot area, in cells)       |
| `--title S`         | `title: "S"`          | none                           |
| `--xlabel S`        | `xlabel: "S"`         | none                           |
| `--ylabel S`        | `ylabel: "S"`         | none                           |
| `--xlim A,B`        | `xlim: [a, b]`        | the data's extent, rounded     |
| `--ylim A,B`        | `ylim: [a, b]`        | the data's extent, rounded     |
| `--canvas C`        | `canvas: :c`          | `braille` (`ascii` with ASCII) |
| `--xscale F`        | `xscale: :f`          | none                           |
| `--yscale F`        | `yscale: :f`          | none (plotted kinds only)      |
| `--xdate [FMT]`     | `xdate: "FMT"`        | by span (plotted kinds only)   |
| `--yerr`            | `yerr: [...]`         | none (line, scatter)           |
| `--threshold N`     | `threshold: n`        | none (line, scatter, stairs)   |
| `--above C`, `--below C` | `above:`, `below:` | red; the series' colour      |
| `--ascii`           | `ascii: true`         | off                            |
| `--color`           | `color: true`         | off                            |
| (none)              | `border: :box`        | by kind                        |

`--width` and `--height` size the plot area, not the whole figure:
labels, frame and legend add to it. A limit of `0,0` means "from the
data", as if none were given.

`--xscale ln|log2|log10` runs every x through the transform before
limits and drawing, so the axis reads in the transformed unit (1 to
1000 under `log10` reads 0 to 3, as unicode_plot's axes do).
`--yscale` does the same to y, for line, scatter, stairs and density
only:

```text
$ tessella chart --xscale log10 --width 30 --height 6 \
    --xlabel 'log10 n' growth.txt
      ┌──────────────────────────────┐
   10 │                           ⢀⣀⠴│ t
      │                      ⣀⡠⠔⠒⠉⠁  │
      │                ⢀⣀⠤⠒⠊⠉        │
      │           ⣀⡠⠔⠒⠉⠁             │
      │    ⢀⣀⡠⠤⠒⠊⠉                   │
    0 │⠤⠒⠊⠉⠁                         │
      └──────────────────────────────┘
      0                              4
                  log10 n
```

`border:` (library only) is `:box` for a full frame, `:bar` for the
corner-and-tick frame bar charts use, or `:none`.

### Options by kind

| CLI                         | Library            | Kinds                |
|-----------------------------|--------------------|----------------------|
| `--style post\|pre`         | `style: :post`     | stairs               |
| `--area`                    | `area: true`       | line, stairs         |
| `--gradient C,C,...\|none` | `gradient: [...]`  | line, stairs, with area |
| `--bins N`                  | `bins: N`          | histogram            |
| `--closed left\|right`      | `closed: :left`    | histogram            |
| `--scale N`                 | `scale: N`         | stem                 |
| `--fill G`                  | `fill: "G"`        | bar, histogram       |
| `--no-eighths`              | `eighths: false`   | bar, histogram       |
| `--track G\|none`           | `track: "G"`/`nil` | bar, histogram       |
| `--orientation O`          | `orientation: :o`  | all but stem         |
| `--blocks B`                | `blocks: :b`       | bar, histogram       |
| `--cell-width N`            | `cell_width: N`    | heatmap              |
| `--colormap C,C,...`        | `colormap: [...]`  | heatmap              |
| `--min A`, `--max B`        | `min:`, `max:`     | heatmap              |
| `--donut`                   | `donut: true`      | pie                  |

The bar defaults are `fill: "█"`, `eighths: true`, `track: "·"`;
under `ascii: true`, `#`, no eighths, and `.`.

Giving an option to a kind that does not take it is an error naming
both, not something silently ignored:

```text
$ tessella chart --kind bar --bins 3 langs.csv
tessella chart: --bins is not valid with --kind bar
Usage: tessella chart [options] [file]
```

## Dates on the x axis

When x is a time, the axis is labelled with dates. On the command
line `--xdate` reads the x column as ISO 8601: a date (`2026-11-05`),
or a date and time (`2026-11-05T14:30`), with an offset (`Z`,
`+01:00`) or none, which means UTC. `temps.txt` is a month of daily
temperatures:

```text
$ head -3 temps.txt
date temp
2026-10-01 12.0
2026-10-02 13.5
```

```text
$ tessella chart --xdate --width 40 --height 6 temps.txt
      ┌────────────────────────────────────────┐
   20 │     ⣀⡠⠤⠤⠤⠤⣀⡀                           │ temp
      │ ⣀⠤⠒⠉       ⠈⠑⠢⢄                    ⡠⠔⠊⠉│
      │⠊⠁              ⠉⠲⢄              ⡠⠖⠉    │
      │                   ⠉⠒⠤⣀⡀    ⢀⡠⠤⠒⠉       │
      │                       ⠉⠉⠉⠉⠉⠉           │
    0 │                                        │
      └────────────────────────────────────────┘
      2026-10-01                      2026-10-30
```

The labels are in UTC, and their format follows the span: `%Y-%m-%d`
for a day or more, `%m-%d %H:%M` for an hour or more, `%H:%M:%S`
below. `--xdate FMT` sets it, in `strftime` form:

```text
$ tessella chart --xdate %d/%m --width 40 --height 6 temps.txt
      ┌────────────────────────────────────────┐
   20 │     ⣀⡠⠤⠤⠤⠤⣀⡀                           │ temp
      │ ⣀⠤⠒⠉       ⠈⠑⠢⢄                    ⡠⠔⠊⠉│
      │⠊⠁              ⠉⠲⢄              ⡠⠖⠉    │
      │                   ⠉⠒⠤⣀⡀    ⢀⡠⠤⠒⠉       │
      │                       ⠉⠉⠉⠉⠉⠉           │
    0 │                                        │
      └────────────────────────────────────────┘
      01/10                                30/10
```

An offset is converted, so the last point here, 23:00 at `+01:00`,
is 22:00 UTC:

```text
$ printf '%s\n' 't v' '2026-11-05T14:00 1' '2026-11-05T18:30 3' \
    '2026-11-05T23:00+01:00 2' | tessella chart --xdate --width 30 --height 4
     ┌──────────────────────────────┐
   3 │             ⣀⠤⠒⠉⠉⠑⠒⠤⢄⣀⡀      │ v
     │        ⢀⡠⠤⠒⠉          ⠈⠉⠒⠢⠤⣀⣀│
     │    ⢀⡠⠔⠊⠁                     │
   1 │⣀⡠⠔⠊⠁                         │
     └──────────────────────────────┘
     11-05 14:00          11-05 22:00
```

The axis spans the data exactly, unless `--xlim` says otherwise
(given as dates too). A date axis takes no `--xscale`; sideways
(`--orientation horizontal`), the dates label the rows. A value that
is not an ISO 8601 date is bad input, exit 1:

```text
$ printf 'x v\n2026-13-01 1\n' | tessella chart --xdate
tessella chart: row 1: x is not an ISO 8601 date: "2026-13-01"
```

In Ruby the x values are `Time`s (or `Date`s, taken as midnight UTC,
or `DateTime`s), and `xdate: "FMT"` sets the format:

```ruby
Tessella.line(times, temps, xdate: "%b %d")
```

## Error bars

`--yerr` (line and scatter) reads a third column as each point's
error, and draws a bar from y − e to y + e along the value axis, after
the line or the points. The axis limits take the bars in. `dose.txt`
holds a measured effect and its error per dose:

```text
$ cat dose.txt
dose effect err
1 2.1 0.4
2 3.0 0.5
3 4.6 0.3
4 5.2 0.8
5 6.9 0.6
6 7.4 1.0
```

```text
$ tessella chart --yerr --width 30 --height 8 dose.txt
     ┌──────────────────────────────┐
   9 │                             ⢠│ effect
     │                        ⡄⢀⣀⣀⡠⢼│
     │                     ⣀⠤⠊⠏⠁   ⠸│
     │                ⢀⣀⡧⠔⠉         │
     │          ⣀⠤⠗⠒⠉⠉⠁ ⠇           │
     │      ⣄⠤⠒⠉                    │
     │⣄⡠⠤⠒⠊⠉⠇                       │
   1 │⠃                             │
     └──────────────────────────────┘
     1                              6
```

```text
$ tessella chart --kind scatter --yerr --ascii --width 30 --height 8 dose.txt
     +------------------------------+
   9 |                             || effect
     |                        .    ||
     |                        |    ||
     |                  |           |
     |            |     |           |
     |      |                       |
     ||     |                       |
   1 |`                             |
     +------------------------------+
     1                              6
```

Sideways (`--orientation horizontal`) the bars run across. Errors are
in data units, and go through `--yscale` with y. `--yerr` needs
exactly three columns, x, y and the error:

```text
$ printf 'x y e f\n1 2 1 1\n' | tessella chart --yerr
tessella chart: --yerr reads x, y and the error: 4 columns
```

In Ruby, `yerr:` on `Tessella.line`, `Tessella.scatter` and `add`
takes one error a point, or `[lows, highs]` for bars that are not
symmetric. An error list of the wrong length, or a negative error, is
refused. With `mark:`, the point stays visible at the middle of its
bar:

```ruby
Tessella.scatter([1, 2, 3], [2, 3, 5], yerr: [[0.5, 0.2, 1], [1, 0.4, 0.5]],
                 mark: "●", width: 20, height: 6)
```

## Thresholds

`--threshold N` (line, scatter, stairs) draws a dashed rule at N
across the plot, readable without colour, and the value axis takes N
in. Under `--color` the cells beyond it take `--above C` (red by
default) and the rest `--below C` (the series' own colour unless
given), each in any [colour form](#colour). Sideways the rule runs
down the plot.

```text
$ tessella chart --threshold 70 --width 30 --height 6 cpu.txt
      ┌──────────────────────────────┐
   90 │  ⢀⡔⠉⠉⠑⣄             ⢀⠖⠉⠉⠑⣄   │
      │⠄⢄⠎⠄⠄⠄⠄⠌⢧⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⢤⠏⠄⠄⠄⠄⠌⢆⠄⠤│
      │⢠⠋       ⢣         ⣰⠃      ⠈⢦ │
      │⠈        ⠈⢧       ⢠⠃        ⠈⢇│
      │           ⢣⡀    ⡰⠃          ⠈│
   10 │            ⠱⢄⣀⣀⠜⠁            │
      └──────────────────────────────┘
      0                             60
```

On the braille canvas the rule is the row of single dots, `⠄`, at 70.
In Ruby: `threshold: 70, above: :red, below: :green`.

## Several series, and marks

From the library, `chart.add` adds a series to a line, scatter,
stairs or density chart. `mark:` draws a series as one glyph in the
cell of each point, over whatever the cell holds, instead of the
kind's own line or dots; the legend shows the glyph before the name.
That is how measured points sit on a fitted curve:

```ruby
# frozen_string_literal: true

# examples/calibration.rb: measured points marked on a fitted line.
require "tessella"

xs = (0..20).map { it * 0.5 }
fit = Tessella.line(xs, xs.map { (0.5 * it) + 1 },
                    name: "fit", width: 30, height: 6, title: "calibration")
fit.add([1, 3, 4.5, 7, 9], [1.4, 2.7, 3.0, 4.9, 5.4],
        name: "measured", mark: "●")
puts fit
```

```text
$ ruby calibration.rb
               calibration
     ┌──────────────────────────────┐
   6 │                         ⢀⡠●⠒⠉│ fit
     │                    ⢀●⠴⠒⠉⠁    │ ● measured
     │               ⣀⡠⠤⠒⠉⠁         │
     │         ●⢀⡠⠔●⠉⠁              │
     │     ⢀⡠⠤⠒⠉⠁                   │
   1 │⣀⡠⠤●⠉⠁                        │
     └──────────────────────────────┘
     0                             10
```

A mark is one character, and ASCII under `ascii: true`. Bar,
histogram, box and stem take no mark.

## Colour

Colour is off by default, because a chart's first home is a document,
where an escape code is garbage. `--color` (`color: true`) colours the
plotted cells with ANSI escapes, one colour per series from the cycle
red, green, yellow, blue, magenta, cyan, white; `add(..., color:
:blue)` picks one. The frame, labels and legend stay plain. Where two
series cross in a cell, the last one drawn colours it.

A colour, in `add(..., color:)` as in a gradient, is one of three
forms: a name (`:red`, `:green`, `:yellow`, `:blue`, `:magenta`,
`:cyan`, `:white`), a 256-colour index (`0..255`, `208` is orange),
or a truecolor `"#rrggbb"`. On the command line, `--gradient` takes
the same three forms, comma-separated: `--gradient
'#2e7d32,#f9a825,#c62828'`. A filled area's colours are covered in
[Filled areas](#filled-areas).

## ASCII

`--ascii` (`ascii: true`) makes the whole chart ASCII from the first
byte: the frame is `+ - |`, the canvas is the ASCII one, bars are `#`
on a `.` track. No part draws Unicode and lets a later pass rewrite
it, so the output is safe in a man page, an RFC-style text or a
source file kept to ASCII. A non-ASCII title, label, bar or series
name is refused, not drawn: on the command line, a non-ASCII data
row is bad input (exit 1) and a non-ASCII `--title`, `--xlabel` or
`--ylabel` a usage error (exit 2).

```text
$ tessella chart --kind histogram --width 30 --bins 8 --ascii normal.txt
                +                              +
   [-3.0, -2.0) |###....................... 8
   [-2.0, -1.0) |##########................ 28
   [-1.0,  0.0) |########################## 72
   [ 0.0,  1.0) |######################.... 61
   [ 1.0,  2.0) |##########................ 28
   [ 2.0,  3.0) |#......................... 3
                +                              +
                           Frequency
```

## What a chart refuses

A chart checks its input before drawing, and raises `ArgumentError`
(exit 2 on the command line) naming what is wrong: an unknown option,
kind, canvas, xscale, stairs style or closed side; a width or height
that is not a positive Integer; x and y of different lengths; a value
that is not a finite number (`nil`, a String, NaN, ±Infinity, or an x
of 0 or less under a log `xscale`); a stem scale that is not
positive.

On the command line, a row that cannot be read is bad input, exit 1,
naming the row and the field:

```text
$ printf '1\nx\n' | tessella chart
tessella chart: row 2: y is not a number: "x"
```

Every row of a bar chart must have as many columns as the first:

```text
$ printf 'a,1,2\nb,3\n' | tessella chart --kind bar
tessella chart: row 2 has 2 columns, row 1 has 3
```

## How tessella differs from unicode_plot

tessella's chart kinds and canvases come from
[unicode_plot](https://github.com/red-data-tools/unicode_plot), which
the test suite uses as an oracle; with unicode_plot's own bar
settings (`fill: "■"`, `"▇"` for histograms, `eighths: false`, `track:
nil`) the output is identical. The departures — sizes below 5 on the
density canvas, wide histogram bins, `10` not `10.0` on an axis,
exact stem leaves, very large constant data, negative bars, CJK
labels — are listed with their reasons in
[DESIGN.md](../DESIGN.md#why-it-is-shaped-so).
