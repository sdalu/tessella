# Charts

A chart turns numbers into a framed figure: a plot area of character
cells, the y extremes on its left, the x extremes under it, a title
above and a legend on the right. There are eight kinds:

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
| `bar`                                 | label, value; a row with more is refused                        |
| `histogram`                           | one column of samples (further columns are ignored)             |
| `box`                                 | one or more columns, one box per column                         |
| `stem`                                | one column; two for the back-to-back form                       |

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

Upright bars need values of 0 or more.

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
`--no-eighths` or `--track`:

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
| `--ascii`           | `ascii: true`         | off                            |
| `--color`           | `color: true`         | off                            |
| (none)              | `border: :box`        | by kind                        |

`--width` and `--height` size the plot area, not the whole figure:
labels, frame and legend add to it. A limit of `0,0` means "from the
data", as if none were given.

`--xscale ln|log2|log10` runs every x through the transform before
limits and drawing, so the axis reads in the transformed unit:

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

The bar defaults are `fill: "█"`, `eighths: true`, `track: "·"`;
under `ascii: true`, `#`, no eighths, and `.`.

Giving an option to a kind that does not take it is an error naming
both, not something silently ignored:

```text
$ tessella chart --kind bar --bins 3 langs.csv
tessella chart: --bins is not valid with --kind bar
Usage: tessella chart [options] [file]
```

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

A bar chart takes exactly a label and a value; a row with more
columns is refused rather than read in part:

```text
$ tessella chart --kind bar trig.txt
tessella chart: row 1 has 3 columns: bar takes label and value
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
