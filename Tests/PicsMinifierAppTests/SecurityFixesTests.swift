import XCTest
@testable import PicsMinifierCore

final class SecurityFixesTests: XCTestCase {

    // MARK: - SecurityUtils Tests

    func testPathValidation() throws {
        // Valid paths should pass
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let homeImage = URL(fileURLWithPath: homeDirectory).appendingPathComponent("Pictures/test.jpg").path
        XCTAssertNoThrow(try SecurityUtils.validateFilePath(homeImage))

        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("temp.png").path
        XCTAssertNoThrow(try SecurityUtils.validateFilePath(tempFile))

        XCTAssertNoThrow(try SecurityUtils.validateFilePath("/Volumes/Drive/image.png"))

        // Directory traversal should fail
        XCTAssertThrowsError(try SecurityUtils.validateFilePath("/Users/test/../../../etc/passwd"))
        XCTAssertThrowsError(try SecurityUtils.validateFilePath("/tmp/test/../../../system"))

        // Invalid paths should fail
        XCTAssertThrowsError(try SecurityUtils.validateFilePath("/root/secret"))
        XCTAssertThrowsError(try SecurityUtils.validateFilePath("/System/important"))

        let siblingHome = URL(fileURLWithPath: homeDirectory).deletingLastPathComponent().appendingPathComponent("otheruser/file.jpg").path
        XCTAssertThrowsError(try SecurityUtils.validateFilePath(siblingHome))
    }

    func testArgumentSanitization() throws {
        // Safe arguments should pass
        let safeArgs = ["input.jpg", "-q", "85", "-o", "output.jpg"]
        XCTAssertNoThrow(try SecurityUtils.sanitizeProcessArguments(safeArgs))

        // Dangerous arguments should fail
        XCTAssertThrowsError(try SecurityUtils.sanitizeProcessArguments(["input.jpg", ";rm -rf /"]))
        XCTAssertThrowsError(try SecurityUtils.sanitizeProcessArguments(["$(malicious)", "-o", "output.jpg"]))
        XCTAssertThrowsError(try SecurityUtils.sanitizeProcessArguments(["input.jpg", "|", "cat /etc/passwd"]))
    }

    func testSecureTempFileCreation() throws {
        let tempFileName = SecurityUtils.createSecureTempFileName(extension: "jpg")

        // Should be a valid filename
        XCTAssertFalse(tempFileName.isEmpty)
        XCTAssertTrue(tempFileName.hasSuffix(".jpg"))
        XCTAssertTrue(tempFileName.count > 10) // Should be reasonably long

        // Should be different each time
        let tempFileName2 = SecurityUtils.createSecureTempFileName(extension: "jpg")
        XCTAssertNotEqual(tempFileName, tempFileName2)
    }

    func testSecureTempDirectory() throws {
        let tempDir = try SecurityUtils.createSecureTempDirectory()

        // Directory should exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempDir.path))

        // Should have proper permissions (owner only)
        let attributes = try FileManager.default.attributesOfItem(atPath: tempDir.path)
        let permissions = attributes[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.intValue, 0o700)

        // Cleanup
        try FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - SafeStatsStore Tests

    func testThreadSafeStatsOperations() {
        let stats = SafeStatsStore.shared

        // Reset to known state
        stats.reset()

        // Test concurrent operations
        let expectation = XCTestExpectation(description: "Concurrent stats operations")
        let iterations = 100
        var completedOperations = 0

        for i in 0..<iterations {
            DispatchQueue.global().async {
                stats.addProcessedFile()
                stats.addSavedBytes(Int64(i * 1000))

                DispatchQueue.main.async {
                    completedOperations += 1
                    if completedOperations == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Verify results
        XCTAssertEqual(stats.processedCount(), iterations)

        let expectedBytes = Int64(iterations * (iterations - 1) / 2 * 1000)
        XCTAssertEqual(stats.totalSavedBytes(), expectedBytes)
    }

    func testOverflowProtection() {
        let stats = SafeStatsStore.shared
        stats.reset()

        // Try to add huge values
        stats.addSavedBytes(Int64.max)
        stats.addSavedBytes(1000)

        // Should not cause overflow
        let totalBytes = stats.totalSavedBytes()
        XCTAssertTrue(totalBytes > 0)
        XCTAssertTrue(totalBytes < Int64.max)
    }

    // MARK: - SafeCSVLogger Tests

    func testThreadSafeLogging() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logURL = tempDir.appendingPathComponent("test_\(UUID().uuidString).csv")
        let logger = SafeCSVLogger(logURL: logURL)

        let expectation = XCTestExpectation(description: "Concurrent logging")
        let iterations = 50
        var completedLogs = 0

        for i in 0..<iterations {
            DispatchQueue.global().async {
                let result = ProcessResult(
                    sourceFormat: "jpg",
                    targetFormat: "jpg",
                    originalPath: "/test/input\(i).jpg",
                    outputPath: "/test/output\(i).jpg",
                    originalSizeBytes: Int64(i * 1000),
                    newSizeBytes: Int64(i * 800),
                    status: "ok"
                )

                logger.log(result)

                DispatchQueue.main.async {
                    completedLogs += 1
                    if completedLogs == iterations {
                        expectation.fulfill()
                    }
                }
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Verify log file exists and has content
        XCTAssertTrue(FileManager.default.fileExists(atPath: logURL.path))

        let content = try String(contentsOf: logURL)
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Should have header + logged entries
        XCTAssertTrue(lines.count >= iterations)

        // Cleanup
        try? FileManager.default.removeItem(at: logURL)
    }

    func testCSVEscaping() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logURL = tempDir.appendingPathComponent("escape_test_\(UUID().uuidString).csv")
        let logger = SafeCSVLogger(logURL: logURL)

        // Log entry with special characters
        let result = ProcessResult(
            sourceFormat: "jpg",
            targetFormat: "jpg",
            originalPath: "/test/file with spaces,\"quotes\".jpg",
            outputPath: "/test/output\nwith\nnewlines.jpg",
            originalSizeBytes: 1000,
            newSizeBytes: 800,
            status: "ok",
            reason: "Test with \"quotes\" and, commas"
        )

        logger.log(result)

        // Verify the content is properly escaped
        let content = try String(contentsOf: logURL)
        XCTAssertTrue(content.contains("\"file with spaces,\"\"quotes\"\".jpg\""))
        XCTAssertTrue(content.contains("\"output\nwith\nnewlines.jpg\""))

        // Cleanup
        try? FileManager.default.removeItem(at: logURL)
    }

    // MARK: - ConfigurationManager Tests

    func testPlatformDetection() {
        let config = ConfigurationManager.shared

        // Should detect valid platform
        XCTAssertNotEqual(config.currentPlatform, .unknown)

        // Tool paths should be available for current platform
        let jpegoptimPath = config.locateTool("jpegoptim")
        // Note: This may be nil in CI environment, which is expected
    }

    func testToolDiscovery() {
        let config = ConfigurationManager.shared

        // Test with non-existent tool
        let fakeTool = config.locateTool("nonexistent_tool_12345")
        XCTAssertNil(fakeTool)

        // Test tool availability check
        let availability = config.checkToolAvailability()
        XCTAssertNotNil(availability)

        // Missing tools should be reported
        if !availability.hasModernTools {
            XCTAssertFalse(availability.missingTools.isEmpty)
        }
    }

    func testConfigurationValidation() {
        let config = ConfigurationManager.shared

        let issues = config.validateConfiguration()
        // Issues array should exist (may be empty if system is properly configured)
        XCTAssertNotNil(issues)

        // Test installation instructions
        let instructions = config.getInstallationInstructions()
        XCTAssertFalse(instructions.isEmpty)
    }

    // MARK: - SecureImageCompressor Tests

    func testSecureFileValidation() {
        let compressor = SecureImageCompressor()

        // Create a test image URL (doesn't need to exist for path validation)
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")

        // Test with various settings
        let settings = AppSettings()

        // This should handle the non-existent file gracefully
        Task {
            let result = await compressor.compressFile(at: testURL, settings: settings)
            XCTAssertEqual(result.status, "error")
        }
    }

    // MARK: - Integration Tests

    func testSecureIntegrationLayer() {
        let integration = SecureIntegrationLayer.shared

        // Test system status
        let status = integration.getSystemStatus()
        XCTAssertNotNil(status)
        XCTAssertTrue(status.memoryUsage > 0)

        // Test installation instructions
        let instructions = integration.getInstallationInstructions()
        XCTAssertFalse(instructions.isEmpty)
    }

    func testCompressionResultCalculations() {
        let results = [
            ProcessResult(
                sourceFormat: "jpg", targetFormat: "jpg",
                originalPath: "/test1.jpg", outputPath: "/test1_out.jpg",
                originalSizeBytes: 1000, newSizeBytes: 800, status: "ok"
            ),
            ProcessResult(
                sourceFormat: "png", targetFormat: "png",
                originalPath: "/test2.png", outputPath: "/test2_out.png",
                originalSizeBytes: 2000, newSizeBytes: 1500, status: "ok"
            )
        ]

        let compressionResult = CompressionResult(
            results: results,
            errors: [],
            duration: 1.5,
            totalSavedBytes: 700
        )

        XCTAssertEqual(compressionResult.successCount, 2)
        XCTAssertEqual(compressionResult.errorCount, 0)
        XCTAssertEqual(compressionResult.totalSavedBytes, 700)

        // Test compression ratio
        let expectedRatio = Double(2300) / Double(3000) // (800 + 1500) / (1000 + 2000)
        XCTAssertEqual(compressionResult.compressionRatio, expectedRatio, accuracy: 0.001)
    }

    // MARK: - Performance Tests

    func testMemoryUsageMonitoring() {
        let integration = SecureIntegrationLayer.shared
        let status = integration.getSystemStatus()

        // Memory usage should be positive and reasonable
        XCTAssertTrue(status.memoryUsage > 0)
        XCTAssertTrue(status.memoryUsageMB > 0)
        XCTAssertTrue(status.memoryUsageMB < 10000) // Less than 10GB (reasonable upper bound)
    }

    func testConcurrentOperations() {
        let expectation = XCTestExpectation(description: "Concurrent operations")
        let iterations = 10
        var completedOperations = 0

        for i in 0..<iterations {
            DispatchQueue.global().async {
                let tempURL = URL(fileURLWithPath: "/tmp/test\(i).jpg")
                let settings = AppSettings()

                Task {
                    let integration = SecureIntegrationLayer.shared
                    let status = integration.getSystemStatus()

                    // Each operation should complete successfully
                    XCTAssertNotNil(status)

                    DispatchQueue.main.async {
                        completedOperations += 1
                        if completedOperations == iterations {
                            expectation.fulfill()
                        }
                    }
                }
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }
}