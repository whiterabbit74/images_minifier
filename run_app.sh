#!/bin/bash

echo "🚀 Launching PicsMinifier..."

# Запускаем приложение в фоне
./.build/debug/PicsMinifierApp &
APP_PID=$!

echo "✅ App launched with PID: $APP_PID"
echo "💡 The SwiftUI app should appear on your screen"
echo "🛑 Press Ctrl+C to stop the app"

# Ждём сигнала завершения
trap "echo '🛑 Stopping app...'; kill $APP_PID 2>/dev/null; exit 0" INT

wait $APP_PID