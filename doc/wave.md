# Timing diagrams

`wave` draws digital signals over time from a WaveDrom-like text: one
signal per line, one character per time step.

```ruby
Tessella.wave(text, period: 4, ascii: false, ruler: false)  # => Block
```

```text
tessella wave [--period N] [--ascii] [--ruler] [--max-width N] [file]
```

## Input

Each line is `name: wave`, optionally followed by `| label label ...`
naming the bus values in order. A lone `---` line draws an empty row
between groups of signals.

| Char | Step                                    |
|------|-----------------------------------------|
| `0`  | low                                     |
| `1`  | high                                    |
| `p`  | a clock period, starting high           |
| `n`  | a clock period, starting low            |
| `x`  | unknown (shaded)                        |
| `z`  | high impedance (dotted)                 |
| `=`  | a bus value, labelled by the next label |
| `.`  | the previous state continues            |

```text
$ cat spi.txt
clk:  p.......
cs:   10.....1
mosi: x=.=.=.x | A0 D0 D1
miso: z..=.=.z | R0 R1
---
irq:  0....1.0
```

```text
$ tessella wave spi.txt
     ──┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐
clk    └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─

     ────┐                       ┌───
cs       └───────────────────────┘

     ▒▒▒▒╳       ╳       ╳       ▒▒▒▒
mosi ▒▒▒▒╳──A0───╳──D0───╳──D1───▒▒▒▒

     ┄┄┄┄┄┄┄┄┄┄┄┄╳       ╳       ┄┄┄┄
miso ┄┄┄┄┄┄┄┄┄┄┄┄╳──R0───╳──R1───┄┄┄┄


                         ┌───────┐
irq  ────────────────────┘       └───
```

## Options

`--period N` (`period:`) is the number of columns per step, 4 by
default; it must be 2 or more, since a clock needs a column to rise
and one to fall. `--ruler` numbers the steps under the diagram.

```text
$ tessella wave --period 3 --ruler spi.txt
     ─┐ ┌┐ ┌┐ ┌┐ ┌┐ ┌┐ ┌┐ ┌┐
clk   └─┘└─┘└─┘└─┘└─┘└─┘└─┘└─

     ───┐                 ┌──
cs      └─────────────────┘

     ▒▒▒╳     ╳     ╳     ▒▒▒
mosi ▒▒▒╳─A0──╳─D0──╳─D1──▒▒▒

     ┄┄┄┄┄┄┄┄┄╳     ╳     ┄┄┄
miso ┄┄┄┄┄┄┄┄┄╳─R0──╳─R1──┄┄┄


                    ┌─────┐
irq  ───────────────┘     └──

     0  1  2  3  4  5  6  7
```

`--ascii` draws `_ | X` and `x`, `-` for unknown and high impedance:

```text
$ tessella wave --ascii spi.txt
     __   _   _   _   _   _   _   _
clk    |_| |_| |_| |_| |_| |_| |_| |_

     ____                         ___
cs       |_______________________|

     xxxx                        xxxx
mosi xxxxX__A0___X__D0___X__D1___xxxx

     ------------                ----
miso ------------X__R0___X__R1___----


                          _______
irq  ____________________|       |___
```

A diagram that ends on `---` does not keep that last blank row: no
block ends with a blank line.

## Errors

An unknown wave character, a line without `name:`, labels that do
not match the `=` steps one for one, or a non-ASCII name or label
under `--ascii` exits 1, naming the line:

```text
$ printf 'clk: pq\n' | tessella wave
tessella wave: line 1: unknown wave character q
```

A `--period` below 2 is a usage error (exit 2).
