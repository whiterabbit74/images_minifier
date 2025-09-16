import Foundation

/// Primary interface for all compression operations with security and performance optimization
public final class SecureIntegrationLayer {
    public static let shared = SecureIntegrationLayer()

    private let statsStore: SafeStatsStore
    private let logger: SafeCSVLogger
    private let compressionService: CompressionService
    private let maxConcurrentOperations = 4
    private let operationQueue: OperationQueue

    private init() {
        self.statsStore = SafeStatsStore.shared

        // Create secure log directory
        let logDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PicsMinifier")
            .appendingPathComponent("Logs") ?? FileManager.default.temporaryDirectory

        let logURL = logDir.appendingPathComponent("compression_log.csv")
        self.logger = SafeCSVLogger(logURL: logURL)

        self.compressionService = CompressionService()

        // Configure operation queue for concurrent processing
        self.operationQueue = OperationQueue()
        self.operationQueue.maxConcurrentOperationCount = maxConcurrentOperations
        self.operationQueue.qualityOfService = .userInitiated
    }

    // MARK: - Main Compression Interface

    /// Compress files with secure validation and progress tracking
    public func compressFiles(
        urls: [URL],
        settings: AppSettings,
        progressCallback: @escaping (Int, Int) -> Void = { _, _ in },
        completion: @escaping ([ProcessResult]) -> Void
    ) {
        Task {
            let results = await processFiles(urls: urls, settings: settings, progressCallback: progressCallback)
            await MainActor.run {
                completion(results)
            }
        }
    }

    private func processFiles(
        urls: [URL],
        settings: AppSettings,
        progressCallback: @escaping (Int, Int) -> Void
    ) async -> [ProcessResult] {
        var results: [ProcessResult] = []
        let totalFiles = urls.count
        var processedCount = 0

        // Process files in batches to manage memory
        let batchSize = min(maxConcurrentOperations, urls.count)

        for i in stride(from: 0, to: urls.count, by: batchSize) {
            let batch = Array(urls[i..<min(i + batchSize, urls.count)])
            let batchResults = await processBatch(batch: batch, settings: settings)

            results.append(contentsOf: batchResults)
            processedCount += batchResults.count

            // Update progress with local copy to avoid concurrency warning
            let currentProcessed = processedCount
            await MainActor.run {
                progressCallback(currentProcessed, totalFiles)
            }
        }

        // Update statistics
        let successfulResults = results.filter { $0.status == "success" }
        let totalSavedBytes = successfulResults.reduce(0) { $0 + ($1.originalSizeBytes - $1.newSizeBytes) }

        statsStore.updateStats(processedFiles: successfulResults.count, savedBytes: totalSavedBytes)

        return results
    }

    private func processBatch(batch: [URL], settings: AppSettings) async -> [ProcessResult] {
        return await withTaskGroup(of: ProcessResult?.self, returning: [ProcessResult].self) { group in
            var results: [ProcessResult] = []

            for url in batch {
                group.addTask {
                    await self.processFile(url: url, settings: settings)
                }
            }

            for await result in group {
                if let result = result {
                    results.append(result)
                    // Log result securely
                    self.logger.log(result)
                }
            }

            return results
        }
    }

    private func processFile(url: URL, settings: AppSettings) async -> ProcessResult? {
        do {
            // Validate file path for security
            let safePath = try SecurityUtils.validateFilePath(url.path)
            let safeURL = URL(fileURLWithPath: safePath)

            // Check file exists and is readable
            guard FileManager.default.isReadableFile(atPath: safePath) else {
                return ProcessResult(
                    sourceFormat: url.pathExtension.lowercased(),
                    targetFormat: url.pathExtension.lowercased(),
                    originalPath: url.path,
                    outputPath: url.path,
                    originalSizeBytes: 0,
                    newSizeBytes: 0,
                    status: "error",
                    reason: "File not readable"
                )
            }

            // Get original file size
            let attributes = try FileManager.default.attributesOfItem(atPath: safePath)
            let originalSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0

            // Check if file is too large (>100MB gets special handling)
            if originalSize > 100 * 1024 * 1024 {
                return await processLargeFile(url: safeURL, settings: settings, originalSize: originalSize)
            }

            // Process with CompressionService
            let result = compressionService.compressFile(at: safeURL, settings: settings)
            return result

        } catch {
            return ProcessResult(
                sourceFormat: url.pathExtension.lowercased(),
                targetFormat: url.pathExtension.lowercased(),
                originalPath: url.path,
                outputPath: url.path,
                originalSizeBytes: 0,
                newSizeBytes: 0,
                status: "error",
                reason: "Security validation failed: \(error.localizedDescription)"
            )
        }
    }

    private func processLargeFile(url: URL, settings: AppSettings, originalSize: Int64) async -> ProcessResult {
        // For large files, use more conservative settings
        var safeSettings = settings
        safeSettings.preset = .balanced // Use balanced instead of quality for large files

        let result = compressionService.compressFile(at: url, settings: safeSettings)
        return result
    }

    // MARK: - System Status

    public func getSystemStatus() -> SystemStatus {
        return SystemStatus(
            isHealthy: true,
            hasModernTools: checkModernTools(),
            availableMemory: getAvailableMemory(),
            diskSpaceAvailable: getDiskSpace()
        )
    }

    private func checkModernTools() -> Bool {
        let tools = ["/opt/homebrew/bin/jpegoptim", "/opt/homebrew/bin/oxipng", "/opt/homebrew/bin/cwebp"]
        return tools.allSatisfy { FileManager.default.isExecutableFile(atPath: $0) }
    }

    private func getAvailableMemory() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Int64(info.resident_size)
    }

    private func getDiskSpace() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        } catch {
            return 0
        }
    }

    // MARK: - Statistics

    public func getStatistics() -> (processedCount: Int, totalSavedBytes: Int64) {
        return statsStore.exportStats()
    }

    public func resetStatistics() {
        statsStore.reset()
    }
}

// MARK: - Supporting Types

public struct SystemStatus {
    public let isHealthy: Bool
    public let hasModernTools: Bool
    public let availableMemory: Int64
    public let diskSpaceAvailable: Int64

    public init(isHealthy: Bool, hasModernTools: Bool, availableMemory: Int64, diskSpaceAvailable: Int64) {
        self.isHealthy = isHealthy
        self.hasModernTools = hasModernTools
        self.availableMemory = availableMemory
        self.diskSpaceAvailable = diskSpaceAvailable
    }
}