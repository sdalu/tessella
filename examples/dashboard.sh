#!/bin/sh
# examples/dashboard.sh -- a dashboard: a chart, a table, meters and a
# sparkline, each drawn to a file and laid out two to a row by
# `compose grid`, then framed.
# usage: sh dashboard.sh
set -eu

cd -- "$(dirname -- "$0")" || exit 1

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/dashboard.XXXXXX") || exit 1

tessella chart --kind bar --width 16 langs.csv > "$tmpdir/1"
tessella table --style rounded langs.csv > "$tmpdir/2"
{
    tessella meter --width 12 --title cpu --title-width 4 0.62
    tessella meter --width 12 --title disk --title-width 4 0.87
} > "$tmpdir/3"
tessella sparkline --width 20 < cpu.txt |
    tessella compose caption --text 'cpu, last hour' - > "$tmpdir/4"
tessella compose grid --columns 2 --gap 3 --align middle \
    "$tmpdir/1" "$tmpdir/2" "$tmpdir/3" "$tmpdir/4" |
    tessella compose frame --title status -
