#!/bin/sh
# examples/status.sh -- telling bad data (exit 1) from a bad call
# (exit 2) in a script: draw what can be drawn, report the rest.
# usage: sh status.sh
set -eu

cd -- "$(dirname -- "$0")" || exit 1

draw() {
    # shellcheck disable=SC3043 # local: every target sh has it
    local status
    status=0
    tessella chart --kind bar --width 20 "$@" 2>/dev/null || status=$?
    case $status in
        0) ;;
        1) printf '%s: bad data, skipped\n' "$*" ;;
        *) printf '%s: bad call (exit %s)\n' "$*" "$status" ;;
    esac
}

draw langs.csv
draw bad.csv
draw --bins 3 langs.csv
