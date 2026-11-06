# Bit fields

`bitfield` draws a packet header or a register as RFC 2360 draws one:
a bit ruler, `+-+` ticks, one row per word, each field's name centred
in its cell. It is always ASCII, as the genre is.

```ruby
Tessella.bitfield(fields, word: 32, octets: false, ruler: true,
                  abbrev: false)                       # => Block
```

```text
tessella bitfield [--word N] [--octets] [--no-ruler] [--abbrev]
                  [--max-width N] [file]
```

## Input

One field per line, `name:bits`, in order from the most significant
bit; or, in Ruby, an Array of `[name, bits]` pairs.

```text
$ cat ipv4.txt
Version:4
IHL:4
DSCP:6
ECN:2
Total Length:16
Identification:16
Flags:3
Fragment Offset:13
TTL:8
Protocol:8
Header Checksum:16
Source Address:32
```

```text
$ tessella bitfield ipv4.txt
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|Version|  IHL  |   DSCP    |ECN|         Total Length          |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Identification         |Flags|     Fragment Offset     |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|      TTL      |   Protocol    |        Header Checksum        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Source Address                         |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

A field longer than what is left of its row continues on the next,
as an Ethernet header's addresses do:

```text
$ tessella bitfield ethernet.txt
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                        Destination MAC                        |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|        Destination MAC        |          Source MAC           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          Source MAC                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|           EtherType           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

## Options

- `--word N` (`word:`): bits per row, 8, 16, 32 (the default) or 64.
- `--octets`: byte-oriented, one tick per octet instead of per bit,
  and no bit ruler.
- `--no-ruler` (`ruler: false`): drop the two ruler rows.
- `--abbrev`: truncate a name too wide for its cell, instead of
  refusing it.
- `--ascii` is accepted and changes nothing.

```text
$ tessella bitfield --word 16 --octets icmp.txt
+---------------+---------------+
|     Type      |     Code      |
+---------------+---------------+
|           Checksum            |
+---------------+---------------+
```

```text
$ tessella bitfield --no-ruler icmp.txt
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     Type      |     Code      |           Checksum            |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
```

A bit is two columns wide, so a 1-bit field has room for one
character and a 4-bit field for seven:

```text
$ printf 'Destination:4\nx:4\n' | tessella bitfield --word 8
tessella bitfield: name "Destination" needs 11 columns, this cell only has 7
```

```text
$ printf 'Destination:4\nx:4\n' | tessella bitfield --word 8 --abbrev
 0
 0 1 2 3 4 5 6 7
+-+-+-+-+-+-+-+-+
|Destin.|   x   |
+-+-+-+-+-+-+-+-+
```

## Errors

A line that is not `name:bits`, a field of zero bits, a name too wide
without `--abbrev`, a name that is not ASCII, or an output wider than `--max-width` exits 1,
naming the line. An unsupported `--word` exits 2.

```text
$ printf 'Type:8\nCode\n' | tessella bitfield
tessella bitfield: line 2: "Code" not name:bits
```
