# Meters

`meter` draws one line: a bar filled to a fraction, between brackets,
with its percentage after it. A progress line in a log, a gauge in a
status report, a column of them in a dashboard.

```ruby
Tessella.meter(fraction, style: :block, width: 20, title: nil,
               label: true, brackets: true, ascii: false)   # => Block
```

```text
tessella meter [--style S] [--width N] [--title T] [--no-label]
               [--no-brackets] [--ascii] FRACTION
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
    tessella meter --style $s --width 12 \
      --title "$(printf '%-9s' $s)" 0.6; \
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

## ASCII

`--ascii` draws the classic style, `=` on a blank track:

```text
$ tessella meter --ascii 0.5
[==========          ] 50 %
```

## A status board

Meters are blocks like any figure, so they stack and frame.
`disks.sh` reads `name fraction` lines and draws one meter each,
their titles padded to one width so the bars line up:

```sh
#!/bin/sh
# examples/disks.sh -- one meter per line of "name fraction", aligned
# by their titles and framed: a small status board.
# usage: sh disks.sh [file]   (default disks.txt)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
input=${1:-disks.txt}

while read -r name fraction; do
    case $name in
        '' | '#'*) continue ;;
    esac
    tessella meter --width 16 --title "$(printf '%-6s' "$name")" \
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
