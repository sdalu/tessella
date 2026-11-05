# Composition

Every figure tessella draws can become a **block**: lines of text,
measured in display columns. Composition takes blocks (or anything
that can become one) and returns a new block, so figures nest: a
chart beside a table, framed, captioned, indented into a comment.

```ruby
# frozen_string_literal: true

# examples/load.rb: a bar chart and a table side by side, framed and
# captioned -- composition of any two figures.
require "tessella"

rows = Tessella::Table.parse(File.read("langs.csv"))
labels = rows.drop(1).map(&:first)
values = rows.drop(1).map { Integer(it[1], exception: false) || it[1].to_f }
plot = Tessella.bar(labels, values, width: 20)
table = Tessella.table(rows, style: :rounded)
fig = Tessella.beside(plot, table, gap: 2, align: :middle)
puts Tessella.caption(Tessella.frame(fig, title: "Load"),
                      text: "Figure 1: lines of code, in thousands")
```

```text
$ ruby load.rb
┌───────────────────── Load ─────────────────────┐
│                                 ╭──────┬─────╮ │
│         ┌                    ┐  │ lang │ loc │ │
│    ruby ┤██████▍········· 12    ├──────┼─────┤ │
│       c ┤████████████████ 30    │ ruby │  12 │ │
│    rust ┤████············ 7.5   │ c    │  30 │ │
│         └                    ┘  │ rust │ 7.5 │ │
│                                 ╰──────┴─────╯ │
└────────────────────────────────────────────────┘

      Figure 1: lines of code, in thousands
```

## Blocks

`Tessella::Block` is a finished figure:

```ruby
block.lines    # => Array of String, no trailing blank on any
block.width    # => display columns of the widest line
block.height   # => number of lines
block.to_s     # => the lines joined, "\n"-terminated
block.check_width!(78)  # ArgumentError naming the line, if wider
```

Every composition function accepts a figure in any form
`Block.from` takes: a `Block`, a `String` of lines, or a chart (any
object whose `to_s` is the figure). The diagram factories
(`Tessella.tree`, `.table`, `.bitfield`, `.wave`, `.seq`, `.image`)
already return blocks.

Three rules hold for every block:

- **Width is display width.** A CJK character counts two columns, a
  combining mark none, an ANSI colour code none, so a coloured or
  CJK-labelled figure lines up by what it shows.
- **A block is never rewritten, only padded** on the right, so its
  own alignment survives every composition. `stack`'s `center:` is
  the one shift, and it moves a whole block at once.
- **What has no width of its own is refused.** A tab (its width
  belongs to the viewer) and an empty block raise `ArgumentError`;
  trailing blank lines are dropped.

## frame

```ruby
Tessella.frame(fig, title: nil, style: nil, pad: 1, fill: nil,
               ascii: false)
```

Draws a border around one figure, with an optional title centred in
its top edge. `pad:` is the blank columns on each side inside the
border; the frame hugs its content vertically.

```text
$ tessella compose frame --title Notes --style rounded note.txt
╭───── Notes ─────╮
│ ruby is 12 kLOC │
│ c is the bulk   │
╰─────────────────╯
```

```text
$ tessella compose frame --pad 0 note.txt
┌───────────────┐
│ruby is 12 kLOC│
│c is the bulk  │
└───────────────┘
```

The styles are `:light` (the default), `:heavy`, `:double`,
`:rounded`, the four dashed ones `:dashed` (`┄┆`), `:dashed_fine`
(`┈┊`), `:heavy_dashed` (`┅┇`) and `:heavy_dashed_fine` (`┉┋`), the
two mixed doubles `:double_h` (double horizontals, `╒═╕`) and
`:double_v` (double verticals, `╓─╖`), and `:ascii`. A name may say
`-` for `_`, and `tessella glyphs border` lists them all with their
glyphs ([glyph sets](glyphs.md)). Four of them:

```text
$ tessella compose frame --style heavy note.txt && \
    tessella compose frame --style double note.txt
┏━━━━━━━━━━━━━━━━━┓
┃ ruby is 12 kLOC ┃
┃ c is the bulk   ┃
┗━━━━━━━━━━━━━━━━━┛
╔═════════════════╗
║ ruby is 12 kLOC ║
║ c is the bulk   ║
╚═════════════════╝
```

```text
$ tessella compose frame --style dashed note.txt && \
    tessella compose frame --style double-h note.txt
┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐
┆ ruby is 12 kLOC ┆
┆ c is the bulk   ┆
└┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┘
╒═════════════════╕
│ ruby is 12 kLOC │
│ c is the bulk   │
╘═════════════════╛
```

### Custom borders

`style:` also takes a set of your own: a String of six glyphs in the
order `tl tr bl br h v` (top-left, top-right, bottom-left,
bottom-right, horizontal, vertical), or a
`Tessella::Borders::Set.new(tl, tr, bl, br, h, v)`. A String that
names a style is that style. Each glyph must take one column.

```text
$ tessella compose frame --style '╓╖╙╜─║' --title Notes note.txt
╓───── Notes ─────╖
║ ruby is 12 kLOC ║
║ c is the bulk   ║
╙─────────────────╜
```

Under `ascii: true` a custom set is drawn if every glyph is ASCII, and
refused otherwise: it is never quietly replaced by `ascii`.

```text
$ tessella compose frame --ascii --style '****=!' note.txt
*=================*
! ruby is 12 kLOC !
! c is the bulk   !
*=================*
```

```text
$ tessella compose frame --ascii --style '╓╖╙╜─║' note.txt
tessella compose: border glyph ╓ conflicts with ascii: true
Usage: tessella compose frame  [--title T] [--style S] [--pad N]
                              [--fill P] [--halo H] BLOCK
       tessella compose shadow [--glyph G] BLOCK
       tessella compose fill   [--pattern P] [--halo H] BLOCK
       tessella compose beside [--gap N] [--align A] BLOCK...
       tessella compose stack  [--gap N] [--rule C] [--center] BLOCK...
       tessella compose indent --prefix STR BLOCK
       tessella compose caption --text T [--above] BLOCK
Every subcommand also takes --ascii and --max-width N.
```

A figure framed in a custom set can still be checked by
[`tessella lint --geometry`](lint.md#geometry), given the same
glyphs with `--border`.

## beside

```ruby
Tessella.beside(fig, fig, ..., gap: 1, align: :top, ascii: false)
```

Sets two or more figures side by side, `gap:` columns apart. A
shorter figure is placed by `align:`: `:top`, `:middle` or `:bottom`.
`plot.txt` is the output of `tessella chart --kind bar --width 20
langs.csv`.

```text
$ tessella compose beside --gap 3 --align middle plot.txt note.txt
        ┌                    ┐
   ruby ┤██████▍········· 12     ruby is 12 kLOC
      c ┤████████████████ 30     c is the bulk
   rust ┤████············ 7.5
        └                    ┘
```

## stack

```ruby
Tessella.stack(fig, fig, ..., gap: 0, rule: nil, center: false,
               ascii: false)
```

Sets two or more figures one under another. `gap:` is the number of
blank lines between two figures. `rule:` is one character, drawn as a
line as wide as the widest figure, with `gap:` blank lines on each
side of it. `center:` centres each narrower figure as a whole.

```text
$ tessella compose stack --rule '─' --center plot.txt note.txt
        ┌                    ┐
   ruby ┤██████▍········· 12
      c ┤████████████████ 30
   rust ┤████············ 7.5
        └                    ┘
──────────────────────────────
       ruby is 12 kLOC
       c is the bulk
```

```text
$ tessella compose stack --gap 1 note.txt note.txt
ruby is 12 kLOC
c is the bulk

ruby is 12 kLOC
c is the bulk
```

## indent

```ruby
Tessella.indent(fig, prefix:, ascii: false)
```

Puts `prefix:` before every line. A line that is empty gets the
prefix without its trailing blank, so `"# "` becomes `"#"` there and
the result keeps the no-trailing-blank rule. This is how a figure
goes into a source comment:

```ruby
# frozen_string_literal: true

# examples/comment.rb: a tree, in ASCII, as a comment block for a
# source file kept to ASCII.
require "tessella"

outline = File.read("outline.txt")
puts Tessella.indent(Tessella.tree(outline, ascii: true),
                     prefix: "# ", ascii: true)
```

```text
$ ruby comment.rb
# tessella
# |-- lib              # the library
# |   |-- tessella.rb  # the entry
# |   `-- tessella
# |       `-- cli
# |-- exe
# |   `-- tessella     # the command
# `-- test
```

## caption

```ruby
Tessella.caption(fig, text:, above: false, ascii: false)
```

Adds a line of text centred on the figure, below it (or above it
with `above: true`), one blank line away.

```text
$ tessella compose caption --text 'Figure 2: lines of code' plot.txt
        ┌                    ┐
   ruby ┤██████▍········· 12
      c ┤████████████████ 30
   rust ┤████············ 7.5
        └                    ┘

   Figure 2: lines of code
```

## shadow

```ruby
Tessella.shadow(fig, glyph: nil, ascii: false)
```

Adds a drop shadow: a glyph one column right of every row but the
first, and a bar under the figure from its second column to the
shadow's. The glyph is `░`, `#` under `ascii: true`; `glyph:`
(`--glyph`) is any glyph one column wide.

```text
$ tessella compose frame note.txt | tessella compose shadow -
┌─────────────────┐
│ ruby is 12 kLOC │░
│ c is the bulk   │░
└─────────────────┘░
 ░░░░░░░░░░░░░░░░░░░
```

```text
$ tessella compose frame --ascii note.txt | tessella compose shadow --ascii -
+-----------------+
| ruby is 12 kLOC |#
| c is the bulk   |#
+-----------------+#
 ###################
```

A shadow drawn this way is the one [the lint](lint.md) expects, so
the figure stays lint-clean.

## fill

```ruby
Tessella.fill(fig, pattern: nil, halo: true, ascii: false)
Tessella.frame(fig, ..., fill: nil, halo: true)
```

Fills every enclosed blank cell with a pattern: inside a box, a
frame, any closed region. What is enclosed is what a flood from the
figure's edge, through blank cells, cannot reach; text, lines and
everything outside are left as they are. Here two hand-drawn boxes in
`boxes.txt`: the space between them is not enclosed, so it stays
blank.

```text
$ tessella compose fill --pattern stipple boxes.txt
┌────┐  ┌────┐
│∴∵∴∵│──│ ok │
└────┘  └────┘
```

`frame`'s `fill:` (`--fill P`) fills only the background the frame
adds, flooding from just inside its border; boxes the content draws
keep their own inside:

```text
$ tessella compose frame --fill light --pad 2 boxes.txt
┌──────────────────┐
│░░┌────┐░░┌────┐░░│
│░░│    │──│ ok │░░│
│░░└────┘░░└────┘░░│
└──────────────────┘
```

### The halo

A pattern packed against letters makes them hard to read, so the fill
keeps a halo of blanks around text: by default (`halo: true`,
`--halo sides`) the cell on each side of a text glyph stays blank, so
a word keeps its shape and the gap between words survives:

```text
$ tessella compose frame --fill light --pad 3 note.txt
┌─────────────────────┐
│░░ ruby is 12 kLOC ░░│
│░░ c is the bulk ░░░░│
└─────────────────────┘
```

`--halo around` (`halo: :around`) also keeps the cells above and
below text blank; `--halo none` or `--no-halo` (`halo: false`) fills
right up to the letters, and between words:

```text
$ tessella compose frame --fill light --pad 3 --halo none note.txt
┌─────────────────────┐
│░░░ruby░is░12░kLOC░░░│
│░░░c░is░the░bulk░░░░░│
└─────────────────────┘
```

Text is any glyph but box drawing and `+ - |`, so lines and borders
take the pattern right up to them.

A pattern is a name from the registry (`light`, the default, `medium`,
`dark`, `solid`, `hatch`, `backhatch`, `cross`, `grid`, `stipple`,
`sparse`, `dotted`, `dots`, `colons`, `hash`, `at`; `tessella glyphs
pattern` lists them) or glyphs of one's own. Several glyphs tile
diagonally. Each glyph must be one column wide, and all must share
one [width class](glyphs.md#width-classes), else the fill would not
line up in every terminal:

```text
$ tessella compose fill --pattern '░▒' boxes.txt
tessella compose: pattern "░▒" mixes width classes: N, A
```

Under `ascii: true` the pattern must be ASCII, and the default is
`colons`:

```text
$ tessella compose frame --ascii --fill hash --pad 3 note.txt
+---------------------+
|## ruby is 12 kLOC ##|
|## c is the bulk ####|
+---------------------+
```

## ASCII

Every function takes `ascii: true`. Its borders are then drawn in
`+ - |`, any other `style:` is refused, and so is any figure or text
holding a non-ASCII character: it is refused rather than rewritten,
so an ASCII figure is ASCII because every part of it was drawn so.

```text
$ tessella chart --kind bar --ascii --width 20 langs.csv | \
    tessella compose frame --ascii --title Load -
+------------- Load -------------+
|         +                    + |
|    ruby |######.......... 12   |
|       c |################ 30   |
|    rust |####............ 7.5  |
|         +                    + |
+--------------------------------+
```

## A larger figure

Diagrams compose like charts. Here a register layout is captioned and
stacked over its timing, under one rule:

```ruby
# frozen_string_literal: true

# examples/datasheet.rb: a register layout over its timing, as a
# datasheet draws them, stacked under one rule.
require "tessella"

register = Tessella.bitfield([["MODE", 4], ["DIV", 8], ["EN", 4]],
                             word: 16)
timing = Tessella.wave(<<~WAVE, period: 4)
    sclk: p.......
    cs:   10.....1
    mosi: x=.=.=.x | CMD ADDR DATA
WAVE
puts Tessella.stack(Tessella.caption(register, text: "CTRL (0x04)",
                                               above: true),
                    timing, gap: 1, rule: "─")
```

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

## `tessella compose`

```text
tessella compose frame   [--title T] [--style S] [--pad N] [--fill P]
                         [--halo H] BLOCK
tessella compose beside  [--gap N] [--align A] BLOCK...
tessella compose stack   [--gap N] [--rule C] [--center] BLOCK...
tessella compose indent  --prefix STR BLOCK
tessella compose caption --text T [--above] BLOCK
tessella compose shadow  [--glyph G] BLOCK
tessella compose fill    [--pattern P] [--halo H] BLOCK
```

`--halo` is `sides`, `around` or `none`; `--no-halo` is `none`.
Each BLOCK is a file, or `-` for stdin (once). Every subcommand also
takes `--ascii`, and `--max-width N` to refuse a result wider than N
columns.

Bad input exits 1, naming the block and the line: a missing file, an
empty block, a tab, a non-ASCII byte under `--ascii`, a result wider
than `--max-width`.

```text
$ tessella compose frame --ascii plot.txt
tessella compose: plot.txt:1: non-ASCII byte
```

```text
$ tessella compose frame --max-width 20 plot.txt
tessella compose: output is 34 columns on line 1 (max-width 20)
```

Composing several files from a script, with a temp directory for the
blocks, is shown in [the command's scripts](cli.md#scripts).

A usage mistake exits 2: an unknown style or alignment, a style
other than `ascii` with `--ascii`, the wrong number of blocks.

```text
$ tessella compose beside plot.txt
tessella compose: beside takes at least two BLOCKs
Usage: tessella compose frame  [--title T] [--style S] [--pad N]
                              [--fill P] [--halo H] BLOCK
       tessella compose shadow [--glyph G] BLOCK
       tessella compose fill   [--pattern P] [--halo H] BLOCK
       tessella compose beside [--gap N] [--align A] BLOCK...
       tessella compose stack  [--gap N] [--rule C] [--center] BLOCK...
       tessella compose indent --prefix STR BLOCK
       tessella compose caption --text T [--above] BLOCK
Every subcommand also takes --ascii and --max-width N.
```
