#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXECUTABLE="$REPO_ROOT/.build/debug/PicsMinifierApp"

cd "$REPO_ROOT"

if [ ! -x "$EXECUTABLE" ]; then
    echo "⚙️  Debug build not found, building now..."
    swift build
fi

if [ ! -x "$EXECUTABLE" ]; then
    echo "❌ Unable to find PicsMinifierApp executable" >&2
    exit 1
fi

echo "🚀 Launching PicsMinifier..."
"$EXECUTABLE" &
APP_PID=$!

echo "✅ App launched with PID: $APP_PID"
echo "🛑 Press Ctrl+C to stop the app"

trap "echo '🛑 Stopping app...'; kill $APP_PID 2>/dev/null; exit 0" INT

wait $APP_PID
