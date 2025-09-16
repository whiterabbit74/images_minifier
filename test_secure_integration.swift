#!/usr/bin/env swift

import Foundation

// Minimal test to verify secure integration components
print("🧪 Testing PicsMinifier Secure Integration...")

// Test 1: SecurityUtils path validation
print("✅ Test 1: SecurityUtils path validation")
do {
    let testPath = "/Users/q/Work/test.jpg"
    let validatedPath = try SecurityUtils.validateFilePath(testPath)
    print("   Path validation successful: \(validatedPath)")
} catch {
    print("   ❌ Path validation failed: \(error)")
}

// Test 2: SafeStatsStore initialization
print("✅ Test 2: SafeStatsStore initialization")
let statsStore = SafeStatsStore.shared
let stats = statsStore.exportStats()
print("   Current stats - Files: \(stats.processedCount), Saved: \(stats.totalSavedBytes) bytes")

// Test 3: SystemStatus check
print("✅ Test 3: SystemStatus check")
let integration = SecureIntegrationLayer.shared
let status = integration.getSystemStatus()
print("   System healthy: \(status.isHealthy)")
print("   Modern tools available: \(status.hasModernTools)")
print("   Available memory: \(status.availableMemory) bytes")
print("   Disk space: \(status.diskSpaceAvailable) bytes")

print("🎉 All basic integration tests completed!")

// Test 4: Create test image directory if it doesn't exist
let testDir = "/Users/q/Work/MAINPROJECTS/pics_minifier/TestImages"
if !FileManager.default.fileExists(atPath: testDir) {
    do {
        try FileManager.default.createDirectory(atPath: testDir, withIntermediateDirectories: true)
        print("✅ Test directory created: \(testDir)")
    } catch {
        print("❌ Failed to create test directory: \(error)")
    }
} else {
    print("✅ Test directory exists: \(testDir)")
}

print("📝 Ready for image compression testing!")