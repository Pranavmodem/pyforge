#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
swiftc passport.swift -o "$scratch/passport-studio"
swift tests/make-fixture.swift "$scratch"
"$scratch/passport-studio" "$scratch/page-one.jpg" "$scratch/output.jpg" 300 300 1
swift tests/inspect.swift "$scratch/page-one.jpg" "$scratch/output.jpg"
if "$scratch/passport-studio" "$scratch/page-one.jpg" "$scratch/invalid.jpg" 300 300 0 '99999,0,20,20' 2>/dev/null; then
    exit 1
fi
test ! -e "$scratch/invalid.jpg"
