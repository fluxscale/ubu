#!/usr/bin/env bash
# Builds the universal (arm64 + x86_64) ubu binary and prints its path on stdout.
# Extra arguments go to `swift build`, e.g. --scratch-path and -Xswiftc -DAPP_STORE.
#
# Refuses to hand back a binary that isn't universal or is older than the sources:
# guessing the output path once shipped a stale arm64-only build (v1.0.1, v1.0.2).
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

swift build -c release --arch arm64 --arch x86_64 ${@+"$@"} >&2
BINARY="$(swift build -c release --arch arm64 --arch x86_64 ${@+"$@"} --show-bin-path)/ubu"

ARCHS="$(lipo -archs "$BINARY")"
if [[ "$ARCHS" != *arm64* || "$ARCHS" != *x86_64* ]]; then
    echo "error: $BINARY is not universal (archs: $ARCHS)" >&2
    exit 1
fi
if [[ -n "$(find "$PROJECT_ROOT/Sources" -name '*.swift' -newer "$BINARY")" ]]; then
    echo "error: $BINARY is older than the sources" >&2
    exit 1
fi

echo "$BINARY"
