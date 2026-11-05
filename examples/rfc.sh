#!/bin/sh
# examples/rfc.sh -- an RFC-style section: a message exchange and the
# header it carries, both ASCII, stacked under a rule and indented
# three columns, as an RFC sets its figures.
# usage: sh rfc.sh
set -eu

cd -- "$(dirname -- "$0")" || exit 1

tmpdir=
cleanup() { [ -z "$tmpdir" ] || rm -rf -- "$tmpdir"; }
trap cleanup EXIT INT HUP TERM
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/rfc.XXXXXX") || exit 1

printf 'Client -> Server: Echo Request\nServer --> Client: Echo Reply\n' |
    tessella seq --ascii > "$tmpdir/seq"
tessella bitfield icmp.txt |
    tessella compose caption --ascii --text 'Figure 1: ICMP header' - \
    > "$tmpdir/header"
tessella compose stack --ascii --gap 1 --rule '-' --center \
    "$tmpdir/seq" "$tmpdir/header" |
    tessella compose indent --ascii --prefix '   ' --max-width 72 -
