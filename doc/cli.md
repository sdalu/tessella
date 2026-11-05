# The `tessella` command

```text
tessella COMMAND [options] [file]
tessella --help
tessella --version
```

The first argument names the command. Each command reads one file,
or stdin when none is given (`compose` reads several), and prints one
figure on stdout. Each has its own `--help`.

| Command    | Draws                                      | Page                           |
|------------|--------------------------------------------|--------------------------------|
| `chart`    | line, scatter, stairs, density, bar, histogram, box, stem | [charts](charts.md) |
| `compose`  | frame, beside, stack, indent, caption      | [composition](composition.md)  |
| `tree`     | an indented outline as a tree              | [tree](tree.md)                |
| `table`    | CSV or TSV rows as a table                 | [table](table.md)              |
| `bitfield` | an RFC-style packet or register layout     | [bitfield](bitfield.md)        |
| `wave`     | a timing diagram                           | [wave](wave.md)                |
| `seq`      | a sequence diagram                         | [seq](seq.md)                  |
| `image`    | a picture as text                          | [images](images.md)            |
| `lint`     | checks a text figure, drawn or hand-made   | [lint](lint.md)                |

## Exit status

Every command keeps one contract:

| Status | Meaning                                                       |
|--------|---------------------------------------------------------------|
| 0      | the figure was drawn (or `--help`, `--version` answered)      |
| 1      | bad input: a file that cannot be read, a malformed line, a value out of range, a figure wider than `--max-width` |
| 2      | a usage mistake: an unknown command or option, a bad option value, an option the command or kind does not take |

The message goes to stderr as `tessella COMMAND: message`, naming the
line, row or block it is about; a usage mistake adds the usage line.

A file that cannot be read is reported the same way by every
command, naming it (`stdin` when it was stdin):

```text
$ tessella table missing.csv
tessella table: cannot read missing.csv: No such file or directory
```

```text
$ tessella chart --kind pie langs.csv
tessella chart: invalid argument: --kind pie
Usage: tessella chart [options] [file]
```

```text
$ tessella
tessella: no command
Usage: tessella COMMAND [options] [file]

Commands:
  chart     line, scatter, stairs, density, bar, histogram,
            box and stem charts
  compose   frame, beside, stack, indent, caption: assemble
            blocks into one figure
  tree      an indented outline as a box-drawing tree
  table     CSV or TSV rows as a framed table
  bitfield  an RFC-style packet / bit-field diagram
  wave      a timing diagram from WaveDrom-like signals
  seq       a sequence diagram from "A -> B: msg" lines
  image     a picture as text: tones, blocks, braille, edges
  lint      check text figures: tabs, widths, invisible
            glyphs, mixed or misaligned structure

tessella COMMAND --help shows a command's options;
tessella --version prints the version.
```

## `--max-width N`

Every diagram command (`compose`, `tree`, `table`, `bitfield`,
`wave`, `seq`, `image`) takes `--max-width N`, and refuses with exit 1
a figure wider than N columns rather than print one that would wrap.
A build that writes figures into a document with an 80-column rule
can let tessella enforce it:

```text
$ tessella seq --max-width 30 login.txt
tessella seq: output is 41 columns, over --max-width 30
```

## `tessella chart`

```text
tessella chart [--kind K] [--width N] [--height N] [--title S]
               [--xlabel S] [--ylabel S] [--xlim A,B] [--ylim A,B]
               [--canvas C] [--xscale F] [--ascii] [--color]
               [--style post|pre] [--bins N] [--closed left|right]
               [--scale N] [--fill G] [--no-eighths] [--track G|none]
               [file]
```

| Option                 | Takes                                  | Default         |
|------------------------|----------------------------------------|-----------------|
| `--kind K`             | `line scatter stairs density bar histogram box stem` | `line` |
| `--width N`            | plot area width, cells                 | 40              |
| `--height N`           | plot area height, cells                | 15              |
| `--title S`            | a title above the frame                |                 |
| `--xlabel S`           | a label under the x axis               |                 |
| `--ylabel S`           | a label left of the y axis             |                 |
| `--xlim A,B`           | x limits                               | from the data   |
| `--ylim A,B`           | y limits                               | from the data   |
| `--canvas C`           | `braille block dot ascii density`      | `braille`       |
| `--xscale F`           | `ln log2 log10`                        |                 |
| `--ascii`              | ASCII only                             | off             |
| `--color`              | ANSI colour in the plot area           | off             |
| `--style S`            | stairs: `post pre`                     | `post`          |
| `--bins N`             | histogram: number of bins              | Sturges' rule   |
| `--closed C`           | histogram: `left right`                | `left`          |
| `--scale N`            | stem: value of one stem step           | 10              |
| `--fill G`             | bar, histogram: bar glyph              | `█` (`#`)       |
| `--no-eighths`         | bar, histogram: whole cells only       |                 |
| `--track G`            | bar, histogram: track glyph, or `none` | `·` (`.`)       |

The input format, column by kind, is in
[charts](charts.md#the-input-format).

## `tessella compose`

```text
tessella compose frame   [--title T] [--style S] [--pad N] BLOCK
tessella compose beside  [--gap N] [--align top|middle|bottom] BLOCK...
tessella compose stack   [--gap N] [--rule C] [--center] BLOCK...
tessella compose indent  --prefix STR BLOCK
tessella compose caption --text T [--above] BLOCK
```

All take `--ascii` and `--max-width N`. A BLOCK is a file, or `-` for
stdin, once. See [composition](composition.md).

## The diagram commands

```text
tessella tree     [--style light|heavy|rounded] [--ascii] [--root NAME] [file]
tessella table    [--tsv] [--no-header] [--style S] [--ascii]
                  [--align SPEC] [--title T] [file]
tessella bitfield [--word 8|16|32|64] [--octets] [--no-ruler] [--abbrev]
                  [file]
tessella wave     [--period N] [--ascii] [--ruler] [file]
tessella seq      [--ascii] [--numbered] [--footer] [file]
tessella image    [--style S] [--width N] [--dither M] [--ramp STR]
                  [--gamma F] [--threshold F] [--edge-threshold F]
                  [--invert] [--ascii] [file]
```

Each also takes `--max-width N`. A frame's `--style` also takes six
glyphs (`tl tr bl br h v`), a table's eleven (those six, then `top_t
bot_t sep_l sep_t sep_r`): see
[custom borders](composition.md#custom-borders). Table styles are `light heavy double
rounded ascii minimal markdown`; image styles `ramp blocks half
quadrant sextant braille edges`, dithers `fs atkinson bayer none`.

## `tessella lint`

```text
tessella lint [--width N] [--prefix STR] [--ruler] [--forbid SEQ]...
              [--web] [--no-wide] [--ascii] [--allow-mixed]
              [--fences] [--geometry] [--border GLYPHS]... [file ...]
tessella lint --alphabet [file ...]
```

Unlike the drawing commands, `lint` takes several files and prints
its findings on stderr, as `FILE:LINE: message`; `--ruler` and
`--alphabet` print on stdout. It exits 1 on any finding. See
[lint](lint.md).

## Pipelines

Every command reads stdin and writes stdout, so they chain; `compose`
reads `-` as stdin:

```text
$ tessella chart --kind bar --width 20 langs.csv | \
    tessella compose caption --text 'Lines of code' -
        ┌                    ┐
   ruby ┤██████▍········· 12
      c ┤████████████████ 30
   rust ┤████············ 7.5
        └                    ┘

        Lines of code
```

## Scripts

The commands are built to be scripted: each reads a file or stdin,
writes the figure on stdout and nothing else, and says what went wrong
by its exit status. The scripts below are in
[examples/](../examples/), POSIX sh for FreeBSD and GNU/Linux alike,
and each runs from any directory.

### Data from another program

Anything that prints columns can feed a chart; a header row names
the series.

```sh
#!/bin/sh
# examples/trig.sh -- data made on the spot by awk, piped straight
# into a chart: a header row names the two series.
# usage: sh trig.sh
set -eu

awk 'BEGIN {
    print "x sin cos"
    for (i = 0; i <= 100; i++)
        printf "%g %g %g\n", i / 10, sin(i / 10), cos(i / 10)
}' |
    tessella chart --title trig --xlabel x --width 30 --height 6
```

```text
$ sh trig.sh
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
                     x
```

### Several figures, one result

`compose` reads only one block from stdin, so the other blocks go
through files; a temp directory, removed on exit, keeps them.

```sh
#!/bin/sh
# examples/report.sh -- a chart and a table drawn from one CSV, set
# side by side, framed and captioned: compose reads one block from
# stdin, so the others go through a temp directory.
# usage: sh report.sh [file.csv]   (default langs.csv)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
csv=${1:-langs.csv}

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/report.XXXXXX") || exit 1

tessella chart --kind bar --width 20 -- "$csv" > "$tmpdir/chart"
tessella table --style rounded -- "$csv" > "$tmpdir/table"
tessella compose beside --gap 2 --align middle \
    "$tmpdir/chart" "$tmpdir/table" |
    tessella compose frame --title Load - |
    tessella compose caption --text "Source: $csv" -
```

```text
$ sh report.sh
┌───────────────────── Load ─────────────────────┐
│                                 ╭──────┬─────╮ │
│         ┌                    ┐  │ lang │ loc │ │
│    ruby ┤██████▍········· 12    ├──────┼─────┤ │
│       c ┤████████████████ 30    │ ruby │  12 │ │
│    rust ┤████············ 7.5   │ c    │  30 │ │
│         └                    ┘  │ rust │ 7.5 │ │
│                                 ╰──────┴─────╯ │
└────────────────────────────────────────────────┘

                Source: langs.csv
```

The same in a loop: one picture in four styles.

```sh
#!/bin/sh
# examples/gallery.sh -- one picture in several styles, each captioned
# with its name, then set side by side.
# usage: sh gallery.sh [image]   (default disc.pgm)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
image=${1:-disc.pgm}

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gallery.XXXXXX") || exit 1

for style in ramp quadrant braille edges; do
    tessella image --style "$style" --width 14 -- "$image" |
        tessella compose caption --text "$style" - > "$tmpdir/$style"
done
tessella compose beside --gap 3 --align bottom \
    "$tmpdir/ramp" "$tmpdir/quadrant" "$tmpdir/braille" "$tmpdir/edges"
```

<!-- tessella: allow-mixed -->
```text
$ sh gallery.sh
      ..                                            ────
   .--===-:.        ▖▞▞▞▖▚        ⠠⡐⡌⡎⡜⡌⡔⡀⡀       ╱──────╲╲
  :=+*##*+=-.     ▗▚▚▛▟▙▛▌▌▚     ⡐⢕⢕⡵⣯⢾⢵⢕⢕⢄      ╱╱╱╱───╲╲╲╲
 .-+*#%%#*+-:     ▘▌▛▟█▙█▜▐▗     ⡊⡎⣗⢿⣽⣿⢯⢯⡪⡢⠂    │││       ││
 .:=+*##*+=-.     ▘▚▀▛▟▜▞▌▌▚     ⠌⡪⡪⡻⡺⡽⣝⠵⡱⠐⠁     ╲╲╲╲──╱╱╱╱╱
   :-====-:.       ▘▘▚▘▌▘▚▝       ⠨⠘⠌⢇⢇⠣⢃⠊       ╲╲──────╱╱
     ....               ▘           ⠁  ⠈           ──────

    ramp          quadrant        braille          edges
```

### Figures for source files and plain-text documents

A tree as a C comment, refused rather than wrapped if it outgrows the
column budget:

```sh
#!/bin/sh
# examples/comment.sh -- a tree as a C block comment, for a header
# kept to ASCII and 72 columns: --max-width fails the build (exit 1)
# rather than let the figure wrap.
# usage: sh comment.sh
set -eu

cd -- "$(dirname -- "$0")" || exit 1

printf '/*\n'
tessella tree --ascii --max-width 69 outline.txt |
    tessella compose indent --ascii --prefix ' * ' -
printf ' */\n'
```

```text
$ sh comment.sh
/*
 * tessella
 * |-- lib              # the library
 * |   |-- tessella.rb  # the entry
 * |   `-- tessella
 * |       `-- cli
 * |-- exe
 * |   `-- tessella     # the command
 * `-- test
 */
```

An RFC-style figure: everything ASCII, stacked, captioned, indented
three columns, and held to 72 columns.

```sh
#!/bin/sh
# examples/rfc.sh -- an RFC-style section: a message exchange and the
# header it carries, both ASCII, stacked under a rule and indented
# three columns, as an RFC sets its figures.
# usage: sh rfc.sh
set -eu

cd -- "$(dirname -- "$0")" || exit 1

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/rfc.XXXXXX") || exit 1

printf 'Client -> Server: Echo Request\nServer --> Client: Echo Reply\n' |
    tessella seq --ascii > "$tmpdir/seq"
tessella bitfield icmp.txt |
    tessella compose caption --ascii --text 'Figure 1: ICMP header' - \
    > "$tmpdir/header"
tessella compose stack --ascii --gap 1 --rule '-' --center \
    "$tmpdir/seq" "$tmpdir/header" |
    tessella compose indent --ascii --prefix '   ' --max-width 72 -
```

```text
$ sh rfc.sh
                      +---------+    +---------+
                      | Client  |    | Server  |
                      +----+----+    +----+----+
                           |              |
                           | Echo Request |
                           |------------->|
                           |              |
                           |  Echo Reply  |
                           |<- - - - - - -|
                           |              |

   -----------------------------------------------------------------

    0                   1                   2                   3
    0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
   |     Type      |     Code      |           Checksum            |
   +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

                         Figure 1: ICMP header
```

### Exit status in a script

Exit 1 is the data's fault, exit 2 the caller's. A script that draws
many inputs can skip a bad file and still stop on a bad call:

```sh
#!/bin/sh
# examples/status.sh -- telling bad data (exit 1) from a bad call
# (exit 2) in a script: draw what can be drawn, report the rest.
# usage: sh status.sh
set -eu

cd -- "$(dirname -- "$0")" || exit 1

draw() {
    # shellcheck disable=SC3043 # local: every target sh has it
    local status
    status=0
    tessella chart --kind bar --width 20 "$@" 2>/dev/null || status=$?
    case $status in
        0) ;;
        1) printf '%s: bad data, skipped\n' "$*" ;;
        *) printf '%s: bad call (exit %s)\n' "$*" "$status" ;;
    esac
}

draw langs.csv
draw bad.csv
draw --bins 3 langs.csv
```

```text
$ sh status.sh
        ┌                    ┐
   ruby ┤██████▍········· 12
      c ┤████████████████ 30
   rust ┤████············ 7.5
        └                    ┘
bad.csv: bad data, skipped
--bins 3 langs.csv: bad call (exit 2)
```

## From Ruby

The command line is a library too, loaded apart from the drawing
library:

```ruby
require "tessella/cli"   # loads tessella, optparse, the commands

status = Tessella::CLI.run(%w[chart --kind bar langs.csv],
                           stdin: $stdin, stdout: $stdout,
                           stderr: $stderr)
```

`CLI.run` returns the exit status instead of exiting, and writes
only to the streams it is given, so a test can pass `StringIO`s.
`require "tessella"` alone loads neither the commands nor `optparse`.
