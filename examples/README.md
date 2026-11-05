# tessella examples

Input files and Ruby scripts the documentation in [doc/](../doc/)
draws its figures from. Run them from this directory, with tessella
installed (`make install`), or from a checkout:

```sh
cd examples
RUBYLIB=../lib ruby load.rb
../exe/tessella chart --kind bar langs.csv
```

## Ruby scripts

| Script           | Shows                                              | In                                  |
|------------------|----------------------------------------------------|-------------------------------------|
| `calibration.rb` | a line chart with measured points marked on it     | [charts](../doc/charts.md)          |
| `load.rb`        | a bar chart beside a table, framed and captioned   | [composition](../doc/composition.md) |
| `datasheet.rb`   | a register layout stacked over its timing diagram  | [composition](../doc/composition.md) |
| `comment.rb`     | an ASCII tree indented as a source comment         | [composition](../doc/composition.md) |
| `fit.rb`         | a table fitted to a width, with a multi-line cell  | [table](../doc/table.md)            |
| `gradient.rb`    | a `Raster` built in Ruby, drawn in three styles    | [images](../doc/images.md)          |
| `refusals.rb`    | what the library refuses, and its messages         | [library](../doc/library.md)        |
| `lint.rb`        | the lint's findings and rulers, from Ruby          | [lint](../doc/lint.md)              |

## Shell scripts

POSIX sh, for FreeBSD and GNU/Linux alike; each finds its inputs
from any directory. `tessella` must be on `PATH`:
`PATH=../exe:$PATH sh report.sh` from a checkout.

| Script       | Shows                                                    |
|--------------|----------------------------------------------------------|
| `trig.sh`    | awk's output piped into a chart                          |
| `report.sh`  | a chart and a table from one CSV, composed via temp files |
| `gallery.sh` | one picture in four styles, captioned, side by side      |
| `comment.sh` | an ASCII tree as a C block comment, held to 72 columns   |
| `rfc.sh`     | an RFC-style figure: seq and bitfield, ASCII, indented   |
| `status.sh`  | exit 1 (bad data) told apart from exit 2 (bad call)      |
| `disks.sh`   | one meter per input line, titles aligned, framed         |
| `gauges.sh`  | upright meters side by side, one per input line          |
| `dashboard.sh` | a chart, a table, meters, a sparkline in a framed grid |

All are shown with their output in
[doc/cli.md](../doc/cli.md#scripts).

## Inputs

| File           | For                     | Holds                                         |
|----------------|-------------------------|-----------------------------------------------|
| `langs.csv`    | `chart`, `table`        | three labels and values, with a header        |
| `trig.txt`     | `chart`                 | `x sin cos`, 101 rows for x in 0..10          |
| `cpu.txt`      | `chart --area`          | 60 load samples between 10 and 90             |
| `temps.txt`    | `chart --xdate`         | a month of daily temperatures, ISO dates      |
| `dose.txt`     | `chart --yerr`          | x, y and an error per point                   |
| `os.csv`       | `chart --kind pie`      | nine shares, for the legend under the disc    |
| `cities.csv`   | `--target cjk`          | a CJK label and an accented one               |
| `ohlc.txt`     | `chart --kind candlestick` | a week of open/high/low/close prices       |
| `growth.txt`   | `chart --xscale`        | x over four decades                           |
| `hosts.csv`    | `chart --kind bar`      | three series per label, for grouped/stacked   |
| `week.txt`     | `chart --kind heatmap`  | a load per day and per three hours            |
| `neg.csv`      | `chart --kind bar`      | negative, positive and zero values            |
| `normal.txt`   | `chart --kind histogram`| 200 roughly normal samples                    |
| `samples.txt`  | `chart --kind box`      | three columns of samples                      |
| `stem.txt`     | `chart --kind stem`     | one column of values                          |
| `ages.txt`     | `chart --kind stem`     | two columns, for the back-to-back form        |
| `bad.csv`      | `status.sh`             | a CSV with a value that is not a number       |
| `plot.txt`     | `compose`               | a bar chart, as `tessella chart` printed it   |
| `disks.txt`    | `disks.sh`              | mount points and how full each is             |
| `boxes.txt`    | `compose fill`          | two hand-drawn boxes joined by a line         |
| `note.txt`     | `compose`               | two lines of text                             |
| `outline.txt`  | `tree`                  | an indented outline with notes                |
| `kinds.csv`    | `table`                 | CSV with quoted fields holding commas         |
| `sizes.tsv`    | `table --tsv`           | tab-separated rows                            |
| `ipv4.txt`     | `bitfield`              | the IPv4 header, up to the source address     |
| `ethernet.txt` | `bitfield`              | fields longer than a row                      |
| `icmp.txt`     | `bitfield`              | a 32-bit ICMP header                           |
| `spi.txt`      | `wave`                  | an SPI transfer: clock, select, buses, an IRQ |
| `login.txt`    | `seq`                   | a login exchange with a self call and a note  |
| `broken.txt`   | `lint`                  | a tab, a trailing blank, a wandering box side |
| `drift.txt`    | `lint --border`         | a frame in a custom set, one side moved       |
| `table-drift.txt` | `lint --ruler`       | a table whose verticals drift on one row      |
| `notes.md`     | `lint --fences`         | Markdown: a table, prose, a flawed diagram    |
| `figure.c`     | `lint --forbid`         | a diagram in a C comment, holding `*/`        |
| `wide.txt`     | `lint --no-wide`        | a CJK label                                   |
| `disc.pgm`     | `image`                 | a 64 × 64 grey disc, bright at its centre     |

`trig.txt`, `normal.txt`, `cpu.txt` and `temps.txt` were generated:

```sh
ruby -e 'puts "x sin cos"; 0.step(10, 0.1) { puts [it.round(1),
    Math.sin(it), Math.cos(it)].join(" ") }' > trig.txt
ruby -e 'srand 7; 200.times {
    puts (Array.new(12) { rand }.sum - 6).round(3) }' > normal.txt
ruby -e '60.times { puts (50 + (40 * Math.sin(it / 6.0))).round }' > cpu.txt
ruby -e 't = Time.utc(2026, 10, 1); puts "date temp"; 30.times { |i|
    puts "#{(t + (i * 86400)).strftime("%Y-%m-%d")} " \
         "#{(12 + (6 * Math.sin(i / 4.0))).round(1)}" }' > temps.txt
```
