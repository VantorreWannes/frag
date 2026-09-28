#!/usr/bin/env bash
set -e

OUT_DIR="${1:-dist}"
mkdir -p "$OUT_DIR"

zig build -Dtarget=x86_64-windows -Doptimize=ReleaseFast
cp zig-out/bin/frag.dll "$OUT_DIR/frag.dll"

zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
cp zig-out/lib/libfrag.so "$OUT_DIR/libfrag.so"

zig build -Dtarget=aarch64-macos -Doptimize=ReleaseFast
cp zig-out/lib/libfrag.dylib "$OUT_DIR/libfrag.dylib"

echo "Done -> $OUT_DIR"
