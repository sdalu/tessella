# Sparklines

A sparkline is a chart one line high and one cell a value, small
enough to sit in a sentence, a table cell or a log line: ▁▂▄▃█▁▂.

```ruby
Tessella.sparkline(values, width: nil, min: nil, max: nil,
                   ascii: false)                    # => Block
```

```text
tessella sparkline [--width N] [--min A] [--max B] [--ascii] [VALUE ...]
```

The command reads the values given, or stdin when there are none,
split on blanks and commas:

```text
$ tessella sparkline 1 5 22 13 53 2 8
▁▂▄▃█▁▂
```

```text
$ printf '1,2\n3 4\n' | tessella sparkline
▁▃▆█
```

Each value takes one of eight steps, `▁` to `█`, from the lowest value
to the highest. Under `--ascii` the steps are `_.-:=+*#`:

```text
$ tessella sparkline --ascii 1 5 22 13 53 2 8
_.:-#_.
```

## Width and range

`--width N` averages the values into N cells, for a long series in a
short space (with fewer values than cells, each is repeated to fill
them). `cpu.txt` holds 60 values:

```text
$ tessella sparkline --width 20 < cpu.txt
▅▇██▇▆▄▃▂▁▁▃▄▆▇██▇▅▄
```

By default the range is the values' own, so every sparkline uses all
eight steps. `--min` and `--max` fix it, so several sparklines share
one scale and can be compared:

```text
$ tessella sparkline --min 0 --max 100 10 50 90
▂▅▇
```

## Errors

A value that is not a number is bad input, exit 1:

```text
$ tessella sparkline 1 x
tessella sparkline: not a number: "x"
```
