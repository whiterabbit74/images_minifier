import Foundation

/// Thread-safe CSV logger with atomic operations and log rotation
public final class SafeCSVLogger {
    private let logURL: URL
    private let queue = DispatchQueue(label: "com.picsminifier.csvlogger", qos: .utility)
    private let maxLogSize: Int64 = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles = 5

    public init(logURL: URL) {
        self.logURL = logURL
        queue.async {
            self.initializeLogFile()
        }
    }

    private func initializeLogFile() {
        let fm = FileManager.default

        // Create directory if needed
        let directory = logURL.deletingLastPathComponent()
        try? fm.createDirectory(at: directory, withIntermediateDirectories: true)

        // Create header if file doesn't exist
        if !fm.fileExists(atPath: logURL.path) {
            let header = "timestamp,sourceFormat,targetFormat,originalPath,outputPath,originalSizeBytes,newSizeBytes,status,reason\n"
            try? header.write(to: logURL, atomically: true, encoding: .utf8)
        }
    }

    public func log(_ result: ProcessResult) {
        queue.async {
            self.writeLogEntry(result)
            self.rotateLogIfNeeded()
        }
    }

    private func writeLogEntry(_ result: ProcessResult) {
        do {
            // Check log size before writing
            let attributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
            if let fileSize = attributes[.size] as? NSNumber, fileSize.int64Value > maxLogSize {
                rotateCurrentLog()
            }

            let timestamp = ISO8601DateFormatter().string(from: Date())

            // Escape CSV fields safely
            let escapedFields = [
                timestamp,
                csvEscape(result.sourceFormat),
                csvEscape(result.targetFormat),
                csvEscape(result.originalPath),
                csvEscape(result.outputPath),
                String(result.originalSizeBytes),
                String(result.newSizeBytes),
                csvEscape(result.status),
                csvEscape(result.reason ?? "")
            ]

            let line = escapedFields.joined(separator: ",") + "\n"

            // Atomic append
            if let data = line.data(using: .utf8) {
                appendToFile(data: data)
            }

        } catch {
            // Log errors to system log instead of failing silently
            print("CSV Logger error: \(error)")
        }
    }

    private func appendToFile(data: Data) {
        do {
            if FileManager.default.fileExists(atPath: logURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logURL)
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } else {
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            // Fallback to atomic write
            let existingData = (try? Data(contentsOf: logURL)) ?? Data()
            let newData = existingData + data
            try? newData.write(to: logURL, options: .atomic)
        }
    }

    private func csvEscape(_ field: String) -> String {
        if field.contains("\"") || field.contains(",") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    private func rotateLogIfNeeded() {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
            if let fileSize = attributes[.size] as? NSNumber, fileSize.int64Value > maxLogSize {
                rotateCurrentLog()
            }
        } catch {
            // File doesn't exist or can't be read - ignore
        }
    }

    private func rotateCurrentLog() {
        let fm = FileManager.default
        let baseURL = logURL.deletingPathExtension()
        let ext = logURL.pathExtension

        // Rotate existing logs
        for i in (1..<maxLogFiles).reversed() {
            let oldLog = baseURL.appendingPathExtension("\(i).\(ext)")
            let newLog = baseURL.appendingPathExtension("\(i+1).\(ext)")

            if fm.fileExists(atPath: oldLog.path) {
                try? fm.removeItem(at: newLog)
                try? fm.moveItem(at: oldLog, to: newLog)
            }
        }

        // Move current log to .1
        let firstRotated = baseURL.appendingPathExtension("1.\(ext)")
        try? fm.removeItem(at: firstRotated)
        try? fm.moveItem(at: logURL, to: firstRotated)

        // Reinitialize current log
        initializeLogFile()
    }

    // MARK: - Safe Reading

    public func readRecentEntries(limit: Int = 100) -> [String] {
        return queue.sync {
            do {
                let content = try String(contentsOf: logURL, encoding: .utf8)
                let lines = content.components(separatedBy: .newlines)
                return Array(lines.suffix(limit + 1).dropFirst()) // Skip header, take last N entries
            } catch {
                return []
            }
        }
    }

    public func getLogFileSize() -> Int64 {
        return queue.sync {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: logURL.path)
                return (attributes[.size] as? NSNumber)?.int64Value ?? 0
            } catch {
                return 0
            }
        }
    }

    // MARK: - Cleanup

    public func cleanupOldLogs() {
        queue.async {
            let fm = FileManager.default
            let baseURL = self.logURL.deletingPathExtension()
            let ext = self.logURL.pathExtension

            // Remove logs older than maxLogFiles
            for i in (self.maxLogFiles + 1)...20 {
                let oldLog = baseURL.appendingPathExtension("\(i).\(ext)")
                try? fm.removeItem(at: oldLog)
            }
        }
    }
}