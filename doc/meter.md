# Meters

`meter` draws one line: a bar filled to a fraction, between brackets,
with its percentage after it. A progress line in a log, a gauge in a
status report, a column of them in a dashboard.

```ruby
Tessella.meter(fraction, style: :block, width: 20, title: nil,
               title_width: nil, label: true, brackets: true,
               orientation: :horizontal, height: 8,
               ascii: false)                                # => Block
```

```text
tessella meter [--style S] [--width N] [--title T] [--title-width N]
               [--no-label] [--no-brackets] [--ascii]
               [--orientation horizontal|vertical] [--height N] FRACTION
```

`FRACTION` is a number from 0 to 1, or a percentage, `45%`.

```text
$ tessella meter 0.5
[██████████··········] 50 %
```

```text
$ tessella meter --width 10 --title disk 37%
disk [███▊······] 37 %
```

`--width` is the bar's cells, 20 by default. The default `block`
style fills its last cell by eighths, so a bar moves by an eighth of
a cell, not a whole one. `--no-label` drops the percentage and
`--no-brackets` the brackets:

```text
$ tessella meter --no-label --no-brackets 0.25
█████···············
```

## Styles

A style is a fill glyph and a track glyph. The named ones are the
meter sets in the [registry](glyphs.md#the-registry):

```text
$ for s in arrow chevron classic rectangle wave block box circle star; do \
    tessella meter --style $s --width 12 --title $s --title-width 9 0.6; \
  done
arrow     [▸▸▸▸▸▸▸▹▹▹▹▹] 60 %
chevron   [›››››››     ] 60 %
classic   [=======     ] 60 %
rectangle [▮▮▮▮▮▮▮▯▯▯▯▯] 60 %
wave      [~~~~~~~_____] 60 %
block     [███████▎····] 60 %
box       [■■■■■■■□□□□□] 60 %
circle    [●●●●●●●○○○○○] 60 %
star      [★★★★★★★☆☆☆☆☆] 60 %
```

`blade` (`▰▱`) and `button` (`⦿⦾`) exist too, but many fonts lack
their glyphs: try them in the reader's font first.
`tessella glyphs meter` lists every set with its width class.

A style of one's own is two glyphs, fill then track, one column each
and of one [width class](glyphs.md#width-classes):

```text
$ tessella meter --style '▰▱' 0.33
[▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱] 33 %
```

```text
$ tessella meter --style '■░' 0.5
tessella meter: meter style "■░" mixes width classes: A, N
```

## Upright meters

`--orientation vertical` stands the bar up: a column `--height` cells
tall (8 by default), filled from the bottom, between `─` caps (`-`
under `--ascii`, none with `--no-brackets`), the title centred above
and the percentage below. The block style tops its column with an
eighth, `▁` to `▇`. An upright meter takes `--height`, not
`--width`, and the other way round across; either one in the wrong
orientation is a usage error.

```text
$ tessella meter --orientation vertical --height 6 --title cpu 0.62
cpu
 ─
 ·
 ·
 ▆
 █
 █
 █
 ─
62 %
```

Upright meters stand side by side with `compose beside`, their
bottoms aligned. `gauges.sh` draws one per line of `disks.txt`:

```sh
#!/bin/sh
# examples/gauges.sh -- upright meters side by side, one per line of
# "name fraction", bottoms aligned: a row of gauges.
# usage: sh gauges.sh [file]   (default disks.txt)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
input=${1:-disks.txt}

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gauges.XXXXXX") || exit 1

n=0
while read -r name fraction; do
    case $name in
        '' | '#'*) continue ;;
    esac
    n=$((n + 1))
    tessella meter --orientation vertical --height 6 --title "$name" \
        -- "$fraction" > "$tmpdir/$n"
done < "$input"

set --
i=1
while [ "$i" -le "$n" ]; do
    set -- "$@" "$tmpdir/$i"
    i=$((i + 1))
done
tessella compose beside --gap 3 --align bottom "$@"
```

```text
$ sh gauges.sh
 /     /home   /var   /tmp
 ─       ─      ─      ─
 ·       ▂      ·      ·
 ·       █      ·      ·
 ▆       █      ·      ·
 █       █      ·      ·
 █       █      ▇      ·
 █       █      █      ▂
 ─       ─      ─      ─
62 %   87 %    31 %   4 %
```

## ASCII

`--ascii` draws the classic style, `=` on a blank track:

```text
$ tessella meter --ascii 0.5
[==========          ] 50 %
```

## A status board

Meters are blocks like any figure, so they stack and frame.
`--title-width N` (`title_width:`) pads a title to N columns, so a
column of meters lines up; a longer title is refused (exit 2).
`disks.sh` reads `name fraction` lines and draws one meter each:

```sh
#!/bin/sh
# examples/disks.sh -- one meter per line of "name fraction", their
# titles padded to one width so the bars line up, framed: a small
# status board.
# usage: sh disks.sh [file]   (default disks.txt)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
input=${1:-disks.txt}

while read -r name fraction; do
    case $name in
        '' | '#'*) continue ;;
    esac
    tessella meter --width 16 --title "$name" --title-width 6 \
        -- "$fraction"
done < "$input" |
    tessella compose frame --title disks -
```

```text
$ sh disks.sh
┌──────────── disks ─────────────┐
│ /      [█████████▉······] 62 % │
│ /home  [█████████████▉··] 87 % │
│ /var   [█████···········] 31 % │
│ /tmp   [▋···············] 4 %  │
└────────────────────────────────┘
```

## Errors

A fraction outside 0..1 (or 0%..100%), an unknown style, a style that
is not two glyphs of one class, or a missing fraction is a usage error,
exit 2:

```text
$ tessella meter 1.5
tessella meter: fraction must be 0..1 or 0%..100%: "1.5"
```
