#!/bin/sh
# examples/comment.sh -- a tree as a C block comment, for a header
# kept to ASCII and 72 columns: --max-width fails the build (exit 1)
# rather than let the figure wrap.
# usage: sh comment.sh
set -eu

cd -- "$(dirname -- "$0")" || exit 1

printf '/*\n'
tessella tree --ascii --max-width 69 outline.txt |
    tessella compose indent --ascii --prefix ' * ' -
printf ' */\n'
