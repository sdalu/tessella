# Rules

`rule` draws a divider: one line in a rule style, with an optional
ornament centred in it. It separates the parts of a report, a log, a
plain-text document.

```ruby
Tessella.rule(width: 78, ornament: nil, style: :light,
              ascii: false)                          # => Block
```

```text
tessella rule [--width N] [--ornament T] [--style S] [--ascii]
```

```text
$ tessella rule --width 30
──────────────────────────────
```

The ornament is any text, centred by display width with a blank on
each side:

```text
$ tessella rule --width 30 --ornament '✦'
───────────── ✦ ──────────────
```

```text
$ tessella rule --width 30 --style double --ornament 'Part II'
══════════ Part II ═══════════
```

The styles are the rule sets in the [registry](glyphs.md#the-registry):
`light` (`─`, the default), `heavy` (`━`), `double` (`═`), `dashed`
(`┄`) and `ascii` (`-`). `--ascii` draws `-`, and refuses an ornament
that is not ASCII:

```text
$ tessella rule --width 30 --ascii --ornament '* * *'
----------- * * * ------------
```

```text
$ tessella rule --ascii --ornament '✦'
tessella rule: ornament is non-ASCII under ascii: true
```

`stack`'s `rule:` draws a plain line between figures; `rule` is the
one to reach for when the line needs a style or an ornament, or
stands alone.
