#!/bin/sh
# examples/report.sh -- a chart and a table drawn from one CSV, set
# side by side, framed and captioned: compose reads one block from
# stdin, so the others go through a temp directory.
# usage: sh report.sh [file.csv]   (default langs.csv)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
csv=${1:-langs.csv}

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/report.XXXXXX") || exit 1

tessella chart --kind bar --width 20 -- "$csv" > "$tmpdir/chart"
tessella table --style rounded -- "$csv" > "$tmpdir/table"
tessella compose beside --gap 2 --align middle \
    "$tmpdir/chart" "$tmpdir/table" |
    tessella compose frame --title Load - |
    tessella compose caption --text "Source: $csv" -
