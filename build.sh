#!/bin/bash
set -e

zig build -Doptimize=ReleaseFast

mkdir -p bin
cp zig-out/bin/wmpartinfo bin/wmpartinfo 2>/dev/null || cp zig-out/bin/wmpartinfo.exe bin/wmpartinfo.exe

cp zig-out/bin/wmnkextract bin/wmnkextract 2>/dev/null || cp zig-out/bin/wmnkextract.exe bin/wmnkextract.exe

echo "Build successful! Binaries placed in bin/"
