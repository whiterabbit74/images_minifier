#!/bin/bash
set -e

# Get the directory of the script (project root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🧹 Cleaning up previous builds and cache..."
swift package clean
rm -rf .build
rm -rf PicsMinifier.app
rm -f PicsMinifierApp

echo "🚀 Building PicsMinifier (Release, Clean Build)..."
# Delegate to create_app.sh which handles build + bundling
./Scripts/create_app.sh

echo "📦 Verifying app bundle..."
if [ -d "PicsMinifier.app" ]; then
    echo "✅ Success! App bundle created at: ./PicsMinifier.app"
    echo "   You can run it with: open PicsMinifier.app"
else
    echo "❌ Build failed: PicsMinifier.app not found."
    exit 1
fi
