# Text styles

`text` writes letters and digits in one of Unicode's styled
alphabets: 𝐛𝐨𝐥𝐝, 𝑖𝑡𝑎𝑙𝑖𝑐, 𝔣𝔯𝔞𝔨𝔱𝔲𝔯, ℍ𝕖𝕝𝕝𝕠, Sᴍᴀʟʟ ᴄᴀᴘꜱ, ⓒⓘⓡⓒⓛⓔⓓ and the
rest. They are characters, not formatting, so they survive where no
markup does: a terminal banner, a commit subject, a plain-text title.

```ruby
Tessella.text("Hello", style: :double_struck)   # => "ℍ𝕖𝕝𝕝𝕠"
Tessella.text("ℍ𝕖𝕝𝕝𝕠", style: :plain)          # => "Hello"
```

```text
tessella text --style S [--strict] [TEXT ...]
tessella text --plain [TEXT ...]
```

The command styles its arguments, joined by blanks, or stdin when
there are none:

```text
$ tessella text --style bold Hello
𝐇𝐞𝐥𝐥𝐨
```

```text
$ tessella text --style double-struck Hello 2024
ℍ𝕖𝕝𝕝𝕠 𝟚𝟘𝟚𝟜
```

```text
$ echo hi | tessella text --style fullwidth
ｈｉ
```

## The styles

`bold`, `italic`, `bold-italic`, `script`, `bold-script`, `fraktur`,
`bold-fraktur`, `double-struck`, `sans`, `sans-bold`, `sans-italic`,
`sans-bold-italic`, `monospace`, `small-caps`, `superscript`,
`subscript`, `circled`, `negative-circled`, `parenthesized`,
`squared`, `negative-squared` and `fullwidth`. In Ruby a style is a
Symbol with `_` for `-`: `:double_struck`.

The forms come from Unicode's own data; the gaps in the mathematical
alphabets are filled from Letterlike Symbols (`ℎ`, `ℬ`, `ℂ`, ...), as
Unicode intends. Capitals keep their case in small caps; `squared`
and the two negative styles have capitals only. `fullwidth` glyphs
are two columns wide.

`--plain` (`style: :plain`) turns any of them back into plain
letters and digits:

```text
$ tessella text --plain 'ℍ𝕖𝕝𝕝𝕠 𝟚𝟘𝟚𝟜'
Hello 2024
```

## Characters without a form

Not every style has every character: digits exist only in `bold`,
`double-struck`, `sans`, `sans-bold` and `monospace`; small caps have
no `x`; most letters have no subscript. Such a character passes
through unchanged, and the command names it on stderr:

```text
$ tessella text --style small-caps 'Hello x'
tessella text: no small-caps form for: x
Hᴇʟʟᴏ x
```

`--strict` (`strict: true`) refuses the text instead: the command
prints nothing and exits 1.

```text
$ tessella text --style small-caps --strict 'Hello x'
tessella text: no small-caps form for: x
```

## When not to

Every style is non-ASCII, so `--ascii` refuses them all. And they are
for a decorative line, not for prose: a screen reader spells them out
or skips them, and a search for "Hello" does not find "ℍ𝕖𝕝𝕝𝕠".
