#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
swiftc scan.swift -o "$scratch/scanfree"
swift tests/make-fixture.swift "$scratch"
"$scratch/scanfree" --grayscale "$scratch/scan.pdf" "$scratch/page-one.jpg" "$scratch/page-two.jpg"
swift tests/inspect.swift "$scratch/scan.pdf"
if "$scratch/scanfree" "$scratch/invalid.pdf" "$scratch/missing.jpg" 2>/dev/null; then
    exit 1
fi
test ! -e "$scratch/invalid.pdf"
