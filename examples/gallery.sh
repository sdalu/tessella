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
