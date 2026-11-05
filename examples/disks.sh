#!/bin/sh
# examples/disks.sh -- one meter per line of "name fraction", their
# titles padded to one width so the bars line up, framed: a small
# status board.
# usage: sh disks.sh [file]   (default disks.txt)
set -eu

cd -- "$(dirname -- "$0")" || exit 1
input=${1:-disks.txt}

while read -r name fraction; do
    case $name in
        '' | '#'*) continue ;;
    esac
    tessella meter --width 16 --title "$name" --title-width 6 \
        -- "$fraction"
done < "$input" |
    tessella compose frame --title disks -
