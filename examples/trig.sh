#!/bin/sh
# examples/trig.sh -- data made on the spot by awk, piped straight
# into a chart: a header row names the two series.
# usage: sh trig.sh
set -eu

awk 'BEGIN {
    print "x sin cos"
    for (i = 0; i <= 100; i++)
        printf "%g %g %g\n", i / 10, sin(i / 10), cos(i / 10)
}' |
    tessella chart --title trig --xlabel x --width 30 --height 6 \
        --canvas block
