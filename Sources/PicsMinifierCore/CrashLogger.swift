import Foundation

private struct CrashLoggerMessageError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

#if canImport(os.log)
import os.log

/// Simple error and crash logging system
public final class CrashLogger {
    public static let shared = CrashLogger()

    private let logger = os.Logger(subsystem: "com.whiterabbit74.picsminifier", category: "CrashLogger")
    private let logFileURL: URL

    private init() {
        let logsDir = AppPaths.logsDirectory()
        logFileURL = logsDir.appendingPathComponent("crash_log.txt")

        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            let header = "PicsMinifier Crash Log\nStarted: \(Date())\n\n"
            try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }

    private let ioQueue = DispatchQueue(label: "com.picsminifier.crashlogger.io", qos: .utility)

    /// Logs error to file and system log
    public func logError(_ error: Error, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let message = "[\(timestamp)] ERROR in \(context): \(error.localizedDescription)"

        // Write to system log
        logger.error("\(message)")

        // Write to file
        appendToFile(message)
    }

    public func logError(_ message: String, context: String = "") {
        logError(CrashLoggerMessageError(message: message), context: context)
    }

    /// Logs a warning
    public func logWarning(_ message: String, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] WARNING in \(context): \(message)"

        logger.warning("\(logMessage)")
        appendToFile(logMessage)
    }

    /// Logs info for debugging
    public func logInfo(_ message: String, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] INFO in \(context): \(message)"

        logger.info("\(logMessage)")
        appendToFile(logMessage)
    }

    /// Logs critical error before potential crash
    public func logCritical(_ message: String, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] CRITICAL in \(context): \(message)"

        logger.critical("\(logMessage)")
        
        // Critical logs should block to ensure write before crash
        ioQueue.sync {
            self.writeToDisk(logMessage)
        }
    }

    private func appendToFile(_ message: String) {
        ioQueue.async {
            self.writeToDisk(message)
        }
    }
    
    private func writeToDisk(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }

        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
             defer { try? fileHandle.close() }
             _ = try? fileHandle.seekToEnd()
             _ = try? fileHandle.write(contentsOf: data)
        } else {
             try? data.write(to: logFileURL)
        }
    }

    /// Get log file URL
    public func getLogFileURL() -> URL {
        return logFileURL
    }

    /// Clear log file
    public func clearLog() {
        let header = "PicsMinifier Crash Log\nCleared: \(Date())\n\n"
        try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
    }
}

#else

public final class CrashLogger {
    public static let shared = CrashLogger()

    private init() {}

    public func logError(_ error: Error, context: String = "") {
        print("[CrashLogger] ERROR in \(context): \(error.localizedDescription)")
    }

    public func logError(_ message: String, context: String = "") {
        logError(CrashLoggerMessageError(message: message), context: context)
    }

    public func logWarning(_ message: String, context: String = "") {
        print("[CrashLogger] WARNING in \(context): \(message)")
    }

    public func logInfo(_ message: String, context: String = "") {
        print("[CrashLogger] INFO in \(context): \(message)")
    }

    public func logCritical(_ message: String, context: String = "") {
        print("[CrashLogger] CRITICAL in \(context): \(message)")
    }

    public func getLogFileURL() -> URL {
        return FileManager.default.temporaryDirectory
    }

    public func clearLog() {}
}

#endif

private extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
