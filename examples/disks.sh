#!/bin/sh
# examples/disks.sh -- one meter per line of "name fraction", aligned
# by their titles and framed: a small status board.
# usage: sh disks.sh [file]   (default disks.txt)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
input=${1:-disks.txt}

while read -r name fraction; do
    case $name in
        '' | '#'*) continue ;;
    esac
    tessella meter --width 16 --title "$(printf '%-6s' "$name")" \
        -- "$fraction"
done < "$input" |
    tessella compose frame --title disks -
