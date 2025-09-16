#!/usr/bin/env swift

import Foundation

print("🔧 Проверка доступности современных компрессоров:")
print("")

let tools = [
    ("jpegoptim", "/opt/homebrew/bin/jpegoptim"),
    ("mozjpeg-cjpeg", "/opt/homebrew/bin/cjpeg"),
    ("oxipng", "/opt/homebrew/bin/oxipng"),
    ("gifsicle", "/opt/homebrew/bin/gifsicle"),
    ("cwebp", "/opt/homebrew/bin/cwebp"),
    ("dwebp", "/opt/homebrew/bin/dwebp"),
    ("avifenc", "/opt/homebrew/bin/avifenc"),
    ("avifdec", "/opt/homebrew/bin/avifdec"),
    ("zopflipng", "/opt/homebrew/bin/zopflipng")
]

var availableCount = 0
var modernCount = 0

for (name, path) in tools {
    let exists = FileManager.default.fileExists(atPath: path)
    let status = exists ? "✅ Доступен" : "❌ Отсутствует"
    print("  \(name): \(status)")

    if exists {
        availableCount += 1
        if name != "jpegoptim" && name != "gifsicle" { // Современные инструменты
            modernCount += 1
        }
    }
}

print("")
print("📊 Статистика:")
print("  - Всего инструментов: \(tools.count)")
print("  - Доступно: \(availableCount)")
print("  - Современных: \(modernCount)")

if modernCount >= 5 {
    print("  🎉 Система готова для Phase 3!")
} else if modernCount >= 3 {
    print("  ⚠️  Частично готова - нужно доустановить инструменты")
} else {
    print("  ❌ Требуется установка современных компрессоров")
}

print("")
print("💡 Для установки недостающих инструментов:")
print("  brew install jpegoptim oxipng gifsicle webp libavif zopfli")