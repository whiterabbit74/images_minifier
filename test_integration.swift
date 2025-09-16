#!/usr/bin/env swift

import Foundation
import UniformTypeIdentifiers

// Импортируем наши модули (если скомпилированы)
/*
import PicsMinifierCore

print("🧪 Тестирование интеграции Phase 3:")
print("")

// Проверяем менеджер компрессоров
let manager = CompressionEngineManager.shared
let statuses = manager.getAllCompressorStatuses()

print("📊 Статус всех компрессоров:")
for (engineType, status, isAvailable) in statuses {
    let icon = isAvailable ? "✅" : "❌"
    print("  \(icon) \(engineType.displayName): \(status)")
}

print("")

// Проверяем SmartSelector
print("🎯 Тестирование SmartCompressorSelector:")
let selector = SmartCompressorSelector.shared

// Тест PNG
if let pngCompressor = selector.selectOptimalCompressor(
    for: .png,
    fileSize: 1024 * 1024,  // 1MB
    settings: CompressionSettings(),
    priority: .maximumCompression
) {
    print("  PNG (1MB, максимальное сжатие): \(pngCompressor.name)")
} else {
    print("  ❌ PNG компрессор не найден")
}

// Тест JPEG
if let jpegCompressor = selector.selectOptimalCompressor(
    for: .jpeg,
    fileSize: 500 * 1024,  // 500KB
    settings: CompressionSettings(quality: 85),
    priority: .balanced
) {
    print("  JPEG (500KB, сбалансированно): \(jpegCompressor.name)")
} else {
    print("  ❌ JPEG компрессор не найден")
}

print("")
print("✅ Интеграция Phase 3 проверена!")
*/

print("⏳ Ожидание завершения сборки для полного тестирования...")