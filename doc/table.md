# Tables

`table` draws rows of text as a framed table, sized to its content,
with numbers right-aligned.

```ruby
Tessella.table(rows, header: true, style: nil, ascii: false,
               align: nil, title: nil, width: nil, min_width: 4,
               color: false)                     # => Block
Tessella::Table.parse(text, tsv: false)          # => Array of rows
```

```text
tessella table [--tsv] [--no-header] [--style S] [--ascii]
               [--align SPEC] [--title T] [--max-width N] [file]
```

## Input

`rows` is an Array of Arrays of Strings or numbers, the first row the
header unless `header: false`. A number is drawn as written (`12`,
`7.5`), and a column of them right-aligns; any other value is refused
by its position: "row 2, column 1: a cell must be a String or a
number: nil". `Table.parse` reads CSV with RFC 4180 quoting
(a quoted field may hold commas, doubled quotes and newlines), or
tab-separated text with `tsv: true`. The command line reads CSV by
default and TSV with `--tsv`.

```text
$ cat kinds.csv
kind,canvas,notes
line,braille,"joins points, one series per column"
bar,none,"negative values split at zero"
stem,none,"back-to-back with two columns"
```

```text
$ tessella table kinds.csv
┌──────┬─────────┬─────────────────────────────────────┐
│ kind │ canvas  │ notes                               │
├──────┼─────────┼─────────────────────────────────────┤
│ line │ braille │ joins points, one series per column │
│ bar  │ none    │ negative values split at zero       │
│ stem │ none    │ back-to-back with two columns       │
└──────┴─────────┴─────────────────────────────────────┘
```

A column whose every body cell is a number is right-aligned:

```text
$ tessella table langs.csv
┌──────┬─────┐
│ lang │ loc │
├──────┼─────┤
│ ruby │  12 │
│ c    │  30 │
│ rust │ 7.5 │
└──────┴─────┘
```

`--no-header` draws every row as body:

```text
$ tessella table --tsv --no-header sizes.tsv
┌──────┬──────┐
│ name │ size │
│ lib  │ 7876 │
│ test │ 5120 │
└──────┴──────┘
```

## Alignment and title

`--align` takes one letter per column, `l`, `r` or `c`; the library
also takes an Array of `:left`, `:right`, `:center`. `--title` adds a
row above the header, centred across the table.

```text
$ tessella table --title Kinds --align lcr kinds.csv
┌──────────────────────────────────────────────────────┐
│                        Kinds                         │
├──────┬─────────┬─────────────────────────────────────┤
│ kind │ canvas  │                               notes │
├──────┼─────────┼─────────────────────────────────────┤
│ line │ braille │ joins points, one series per column │
│ bar  │  none   │       negative values split at zero │
│ stem │  none   │       back-to-back with two columns │
└──────┴─────────┴─────────────────────────────────────┘
```

## Styles

`light` (the default), `heavy`, `double`, `rounded`, the four
dashed ones (`dashed`, `dashed_fine`, `heavy_dashed`,
`heavy_dashed_fine`), the two mixed doubles `double_h` and
`double_v`, `ascii`, `minimal` (dividers only, no outer frame) and
`markdown` (a GitHub pipe table, ready to paste). The mixed doubles
bring their own tees, `╤ ╧ ╞ ╪ ╡` and `╥ ╨ ╟ ╫ ╢`:

```text
$ tessella table --style double_v langs.csv
╓──────╥─────╖
║ lang ║ loc ║
╟──────╫─────╢
║ ruby ║  12 ║
║ c    ║  30 ║
║ rust ║ 7.5 ║
╙──────╨─────╜
```

```text
$ tessella table --style minimal kinds.csv
       ╷         ╷
  kind │ canvas  │ notes
╶──────┼─────────┼─────────────────────────────────────╴
  line │ braille │ joins points, one series per column
  bar  │ none    │ negative values split at zero
  stem │ none    │ back-to-back with two columns
       ╵         ╵
```

```text
$ tessella table --style markdown kinds.csv
| kind | canvas  | notes                               |
|------|---------|-------------------------------------|
| line | braille | joins points, one series per column |
| bar  | none    | negative values split at zero       |
| stem | none    | back-to-back with two columns       |
```

```text
$ tessella table --style ascii kinds.csv
+------+---------+-------------------------------------+
| kind | canvas  | notes                               |
+------+---------+-------------------------------------+
| line | braille | joins points, one series per column |
| bar  | none    | negative values split at zero       |
| stem | none    | back-to-back with two columns       |
+------+---------+-------------------------------------+
```

### Custom borders

`--style` (`style:`) also takes eleven glyphs: a frame's six (`tl tr
bl br h v`), then the five tees, in the order `top_t bot_t sep_l
sep_t sep_r` (the tee on the top edge, on the bottom edge, at the
left end of the header rule, its crossings, its right end):

```text
$ tessella table --style '╒╕╘╛═│╤╧╞╪╡' langs.csv
╒══════╤═════╕
│ lang │ loc │
╞══════╪═════╡
│ ruby │  12 │
│ c    │  30 │
│ rust │ 7.5 │
╘══════╧═════╛
```

Six glyphs are not enough for a table:

<!-- tessella: allow-mixed -->
```text
$ tessella table --style '╓╖╙╜─║' langs.csv 2>&1 | \
    fold -s -w 72 | sed 's/ $//'
tessella table: a table's border set needs 11 glyphs, its tees after
the six of a frame: "╓╖╙╜─║"
Usage: tessella table [options] [file]  (stdin if none)
    --tsv --no-header --align SPEC --style NAME|GLYPHS --[no-]ascii
    --title TEXT --max-width N
```

### ASCII

Under `ascii: true` a named style draws as `ascii`; a custom set is
drawn if it is all ASCII and refused if not. A cell or title that is
not ASCII is refused.

```text
$ tessella table --ascii --style '****=!+++++' langs.csv
*======+=====*
! lang ! loc !
+======+=====+
! ruby !  12 !
! c    !  30 !
! rust ! 7.5 !
*======+=====*
```

## Multi-line cells, and fitting a width

These two are library options, not command-line flags.

A cell holding `"\n"` draws on several lines within its row,
top-aligned. `width: N` fits the framed table to N columns. It
narrows the widest column one column at a time, then whichever is
widest by then, so wide columns come down together and a narrow one
is never cut first. The narrowed columns' cells are word-wrapped, a
word too long for its column breaking inside.

```ruby
# frozen_string_literal: true

# examples/fit.rb: a table fitted to a width. At 40 columns only the
# widest column narrows and wraps; at 26 it has come down to the next
# widest, and both narrow together. A cell holding a newline keeps its
# own lines. Fitted to 20, the table is refused, naming the width it
# needs.
require "tessella"

rows = Tessella::Table.parse(File.read("kinds.csv"))
rows << ["box", "none", "quartiles\nand whiskers"]
[40, 26, 20].each do |width|
    puts Tessella.table(rows, width: width)
rescue ArgumentError => e
    puts e.message
end
```

```text
$ ruby fit.rb
┌──────┬─────────┬─────────────────────┐
│ kind │ canvas  │ notes               │
├──────┼─────────┼─────────────────────┤
│ line │ braille │ joins points, one   │
│      │         │ series per column   │
│ bar  │ none    │ negative values     │
│      │         │ split at zero       │
│ stem │ none    │ back-to-back with   │
│      │         │ two columns         │
│ box  │ none    │ quartiles           │
│      │         │ and whiskers        │
└──────┴─────────┴─────────────────────┘
┌──────┬────────┬────────┐
│ kind │ canvas │ notes  │
├──────┼────────┼────────┤
│ line │ braill │ joins  │
│      │ e      │ points │
│      │        │ , one  │
│      │        │ series │
│      │        │ per    │
│      │        │ column │
│ bar  │ none   │ negati │
│      │        │ ve     │
│      │        │ values │
│      │        │ split  │
│      │        │ at     │
│      │        │ zero   │
│ stem │ none   │ back-t │
│      │        │ o-back │
│      │        │ with   │
│      │        │ two    │
│      │        │ column │
│      │        │ s      │
│ box  │ none   │ quarti │
│      │        │ les    │
│      │        │ and    │
│      │        │ whiske │
│      │        │ rs     │
└──────┴────────┴────────┘
table needs 22 columns at the least (min_width 4)
```

No column narrows below `min_width:` (4 by default), or below its
own width when that is smaller. When every column is at that floor
and the table is still too wide, it is refused rather than drawn
wider than asked, and the message names the width it needs: the last
line above.

The `markdown` style refuses multi-line cells and `width:`: a pipe
table cannot hold either.

## Colour

An ANSI colour code in a cell takes no column. It survives padding,
and wrapping too: it is closed at the end of each wrapped line and
reopened on the next, so every line stands on its own. `color: true`
sets the header in bold.

## Errors

Bad input is refused naming the line (exit 1): an unterminated
quoted field, a row with a different number of fields from the
first, a non-ASCII cell or title under `--ascii`, a table wider than
`--max-width`.

```text
$ printf 'a,b\nc\n' | tessella table
tessella table: line 2: expected 2 fields, got 1
```

An unknown style or a malformed `--align` is a usage error (exit 2).
