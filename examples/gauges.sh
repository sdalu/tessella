#!/bin/sh
# examples/gauges.sh -- upright meters side by side, one per line of
# "name fraction", bottoms aligned: a row of gauges.
# usage: sh gauges.sh [file]   (default disks.txt)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
input=${1:-disks.txt}

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/gauges.XXXXXX") || exit 1

n=0
while read -r name fraction; do
    case $name in
        '' | '#'*) continue ;;
    esac
    n=$((n + 1))
    tessella meter --orientation vertical --height 6 --title "$name" \
        -- "$fraction" > "$tmpdir/$n"
done < "$input"

set --
i=1
while [ "$i" -le "$n" ]; do
    set -- "$@" "$tmpdir/$i"
    i=$((i + 1))
done
tessella compose beside --gap 3 --align bottom "$@"
