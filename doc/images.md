# Pictures

`image` draws a picture as text: a logo for a banner, a plot or a
screenshot for a terminal, a photograph as a curiosity.

```ruby
Tessella.image(source, style: :ramp, width: 78, ramp: nil, gamma: 1.0,
               threshold: 0.5, dither: :fs, invert: false,
               edge_threshold: 0.3, ascii: false)        # => Block
```

```text
tessella image [--style S] [--width N] [--dither M] [--ramp STR|NAME]
               [--gamma F] [--threshold F] [--edge-threshold F]
               [--invert] [--ascii] [--max-width N] [file]
```

## Sources

`source` is a `Tessella::Raster`, an IO, or a String of image bytes.
The format is told by the bytes' own signature, not a file name:

- **PGM and PPM** (P2, P3, P5, P6) and **PNG** decode with nothing
  installed, in plain Ruby.
- **Anything else** (JPEG, GIF, TIFF, WebP, ...) needs the `rmagick`
  gem. tessella uses it when it is installed and never requires it;
  without it the image is refused, naming the way round: convert to
  PGM first.

```text
$ printf 'GIF89a' | tessella image
tessella image: not a PNM or PNG image, and the rmagick gem is not installed: install it, or convert the image first (magick IMAGE pgm:- | tessella image)
```

```sh
magick photo.jpg pgm:- | tessella image --width 60
```

Colour becomes grey by Rec. 601 luma, and transparency is laid over
black, so a transparent pixel is empty.

A `Raster` can also be built in Ruby, from any function: width,
height, and `width * height` grey values in 0..1, row by row from the
top, 1.0 the brightest.

```ruby
# frozen_string_literal: true

# examples/gradient.rb: a Raster built in Ruby -- no image file --
# drawn in three styles, side by side.
require "tessella"

w = h = 48
luma = (0...h).flat_map do |y|
    (0...w).map { |x| Math.hypot(x - 24, y - 24) < 22 ? x / 47.0 : 0 }
end
raster = Tessella::Raster.new(width: w, height: h, luma: luma)
figs = %i[ramp blocks braille].map do |style|
    Tessella.caption(Tessella.image(raster, style: style, width: 16),
                     text: style.to_s)
end
puts Tessella.beside(*figs, gap: 3)
```

```text
$ ruby gradient.rb
     .:::-:.             ░░░░░░            ⢀⠠⡠⡠⡠⡄⡀
   .:-==++*#*-        ░░░▒▒▒▒▓▓▓░        ⠠⡈⡢⢱⠱⡱⣹⡪⡯⣧⢆
  .::-==++*##%*      ░░░░▒▒▒▒▓▓▓▓▓       ⠅⡂⡊⡢⡣⡫⡲⣝⢽⣺⣟⣧
 ..::-==++*##%%-     ░░░░▒▒▒▒▓▓▓▓█░     ⢁⠂⠢⡑⢌⢎⢎⢞⢮⣻⣺⡽⣟⡇
 ..::-==++*##%%-     ░░░░▒▒▒▒▓▓▓▓█░     ⡐⠨⠨⢨⠢⡣⡣⣫⡺⣺⢮⢿⡿⡇
 ..::-==++*##%#      ░░░░▒▒▒▒▓▓▓▓▓      ⠐⡈⢌⠢⡱⡸⡸⡜⡮⣳⣻⢯⡿⠁
  .::-==++*##+        ░░░▒▒▒▒▓▓▓▒       ⠐⠐⠄⠕⡌⢎⢎⢮⣫⡳⡯⡏⠁
    .::--=--            ░░░░▒░░           ⠁⠑⠸⠸⠸⠪⠚⠊⠁

      ramp              blocks            braille
```

## Styles

The style trades tone for resolution. `ramp` and `blocks` give one
tone per character cell; the others pack several on/off pixels into a
cell, using dithering for tone; `edges` draws outlines.

| Style      | Pixels per cell | Glyphs                          |
|------------|-----------------|---------------------------------|
| `ramp`     | 1               | `` .:-=+*#%@`` (or `--ramp`)    |
| `blocks`   | 1               | ` ░▒▓█`                         |
| `half`     | 1 × 2           | `▀ ▄ █`                         |
| `quadrant` | 2 × 2           | `▘▝▀▖▌▞▛▗▚▐▜▄▙▟█`               |
| `sextant`  | 2 × 3           | Unicode 13 sextants `🬀`…`🬻`      |
| `braille`  | 2 × 4           | braille patterns                |
| `octant`   | 2 × 4           | Unicode 16 octants (see below)  |
| `edges`    | 1               | `─ │ ╱ ╲`, Sobel contours       |

`disc.pgm` is a 64 × 64 grey disc, brightest at its centre:

```text
$ tessella image --width 24 disc.pgm

        ...::...
     .::--====---:.
    :--=+++**+++==-:.
   :-==+**####**++=-:.
  .:-=+**#%%%%##*+==:.
  .:-=+*##%%%%##*+==:.
  .:-=++**#####*++=-:.
   .:-==+++***++==-:.
     .:--======--:.
       ..::::::..
```

```text
$ tessella image --style blocks --width 24 disc.pgm

          ░░░░░
      ░░░▒▒▒▒▒▒░░░
    ░░▒▒▒▒▒▒▒▒▒▒▒▒░░
   ░░▒▒▒▓▓▓▓▓▓▓▓▒▒▒░░
   ░░▒▒▓▓▓▓██▓▓▓▓▒▒▒░░
   ░░▒▒▓▓▓▓███▓▓▓▒▒▒░░
   ░░▒▒▒▓▓▓▓▓▓▓▓▒▒▒░░
    ░░▒▒▒▒▒▓▓▒▒▒▒▒░░
      ░░░▒▒▒▒▒▒░░░░
        ░░░░░░░░
```

```text
$ tessella image --style braille --width 24 disc.pgm

        ⢀ ⢄⠠⠠⠠⢀⢀
      ⠄⢌⢢⢡⢱⢸⢘⢜⠔⡔⡨⠠⡀
    ⠠⠡⡣⡱⡱⡱⣕⢵⣣⡳⣕⢕⡜⡌⡢⢁
   ⠠⡑⢕⢱⡱⣝⢮⣗⣯⢾⣺⢮⡳⣕⢕⢜⠄⢅
   ⢅⠪⡪⣪⢺⣺⢽⣾⣻⣿⣽⢯⣞⢮⡣⡣⡃⢅⠐
   ⠢⡑⢕⢕⣝⢾⢽⡾⣿⢿⣽⣻⣺⢵⡹⡸⡨⢂⠂
   ⡁⠪⡸⡸⡸⣕⢯⢯⣻⢽⣳⢽⡪⡇⡇⡇⡪⠐
    ⠡⢂⢕⢱⠱⡍⣗⢵⢫⢎⢧⢣⢣⠣⢊⠐⠈
     ⠂⠐⠌⡊⡪⠢⠣⡣⢃⠇⢕⠐⠅⠂
      ⠈ ⠂⠂⠡⠑⠨⠠⠑ ⠁
```

```text
$ tessella image --style edges --width 24 disc.pgm

        ────────
     ╱────────────╲
    ╱╱╱╱────────╲╲╲╲
                    ╲


                    ╱
    ╲╲╲╲────────╱╱╱╱
     ╲────────────╱
       ──────────
```

[examples/gallery.sh](../examples/gallery.sh) draws one picture in
four styles side by side ([output](cli.md#several-figures-one-result)).

The sextant glyphs are recent (Unicode 13, 2020): check that the
reader's font has them before using `sextant`.

`octant` packs 2 × 4 pixels into a cell, as braille does, but as
solid blocks rather than dots, so a picture keeps its tone where
braille turns grey. Its glyphs are Unicode 16 (2024), and only the
newest terminals draw them (Ghostty and its like); elsewhere each
cell shows as a box or a blank. That is why this page shows no
octant render: try `tessella image --style octant disc.pgm` in your
own terminal.

## Tone

- `--width N`: the picture's width in cells, 78 by default; the
  height follows from the image's aspect, a cell being about twice as
  tall as wide.
- `--gamma F`: every tone t in 0..1 is drawn as t to the power F;
  above 1 pushes the mid-tones toward empty, below 1 toward full.
- `--invert`: tones are drawn as 1 − t. By default a bright pixel
  gets a dense glyph, which suits light text on a dark terminal;
  invert for dark text on a light page.
- `--ramp STR`: the tone glyphs for `ramp`, from empty to full, or
  the name of a ramp in the [registry](glyphs.md#the-registry):
  `ramp` (the default), `blocks`, `long` (70 ASCII glyphs, for finer
  tone) or `hatch`. A name wins over the same letters taken as
  glyphs.
- `--threshold F`: the tone at which a pixel is on, in the pixel
  styles (0.5 by default).
- `--dither M`: how the pixel styles render tone: `fs`
  (Floyd-Steinberg, the default), `atkinson`, `bayer` (ordered), or
  `none` (a plain threshold).
- `--edge-threshold F`: the gradient strength an `edges` outline
  needs (0.3 by default).

```text
$ tessella image --style braille --dither none --width 24 disc.pgm



       ⢀⣤⣾⣿⣿⣿⣿⣷⣦⡀
      ⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦
      ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆
      ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠇
      ⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡟
       ⠈⠻⣿⣿⣿⣿⣿⣿⠿⠋
          ⠈⠉⠉⠁
```

```text
$ tessella image --ramp ' .oO@' --width 20 disc.pgm

       .......
    ..oooooooo..
   ..oooOOOOOooo.
  ..ooOOO@@OOOoo..
  ..ooOOO@@OOOoo..
   .oooOOOOOOooo..
    ..oooooooo..
      ........
```

```text
$ tessella image --ramp long --width 30 disc.pgm

          .`^",:,"`'
       ',!<_?][[]?-~i;`
     ':<]{(/fjrrjft\)}_l^
    ^i-1/rucYUJJJYXvxf(]~I.
   ^i?1tnzJQOmqqwZ0CYvj([~;.
  .I+}\xzJ0wdhooakpZLYut)?>^
  '!-1/nYQmdh#8%WokqOJcj|[~:
  .l_{\xXCOqba##*hdmQUvf(]<"
   ">])fuXC0mqddpwZQUcr|}_l.
    :<](fxcXJCLQLCUzur\}_!`
     ^l_}(/frxnnnxjt|1?>:.
       ^l<_]}{11{}[-+i,.
         .`,;Il!l;:^'
```

```text
$ tessella image --ramp hatch --width 20 disc.pgm

       ·······
    ··∘∘∘∘∘∘∘∘··
   ··∘∘∘╱╱╱╱╱∘∘∘·
  ··∘∘╱╱╱╳╳╱╱╱∘∘··
  ··∘∘╱╱╱╳╳╱╱╱∘∘··
   ·∘∘∘╱╱╱╱╱╱∘∘∘··
    ··∘∘∘∘∘∘∘∘··
      ········
```

## ASCII

`--ascii` allows only the `ramp` style, with an ASCII ramp:

```text
$ tessella image --style blocks --ascii disc.pgm
tessella image: ascii: true allows only style: :ramp, not :blocks
```

## Errors

A picture that would render blank — `edges` on a flat image, a
threshold above every tone — is refused, naming what to change,
rather than printed as nothing (exit 1):

```text
$ tessella image --style braille --threshold 1 --dither none disc.pgm
tessella image: the picture renders blank at style braille: lower threshold, or try invert or another style
```

A malformed or truncated image is bad input (exit 1); an unknown
style or dither, or a style that `--ascii` does not allow, is a usage
error (exit 2).
