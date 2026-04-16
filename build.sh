#!/usr/bin/env bash
# Build BuildBrowser — macOS, no external dependencies
set -e

BUILD_DIR="build"

echo "→ Configuring…"
cmake -S . -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release

echo "→ Building…"
cmake --build "$BUILD_DIR" --parallel "$(sysctl -n hw.logicalcpu)"

echo ""
echo "✓ Done."
echo "  Run:    open $BUILD_DIR/BuildBrowser.app"
echo "  Or:     $BUILD_DIR/BuildBrowser.app/Contents/MacOS/BuildBrowser"
