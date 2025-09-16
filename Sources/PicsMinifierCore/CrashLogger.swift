import Foundation

#if canImport(os.log)
import os.log

/// Простая система логирования ошибок и крашей
public final class CrashLogger {
    public static let shared = CrashLogger()

    private let logger = os.Logger(subsystem: "com.whiterabbit74.picsminifier", category: "CrashLogger")
    private let logFileURL: URL

    private init() {
        let logsDir = AppPaths.logsDirectory()
        logFileURL = logsDir.appendingPathComponent("crash_log.txt")

        // Создаем файл лога если его нет
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            let header = "PicsMinifier Crash Log\nStarted: \(Date())\n\n"
            try? header.write(to: logFileURL, atomically: true, encoding: .utf8)
        }
    }

    /// Логирует ошибку в файл и системный лог
    public func logError(_ error: Error, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let message = "[\(timestamp)] ERROR in \(context): \(error.localizedDescription)"

        // Пишем в системный лог
        logger.error("\(message)")

        // Пишем в файл
        appendToFile(message)
    }

    /// Логирует предупреждение
    public func logWarning(_ message: String, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] WARNING in \(context): \(message)"

        logger.warning("\(logMessage)")
        appendToFile(logMessage)
    }

    /// Логирует информацию для отладки
    public func logInfo(_ message: String, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] INFO in \(context): \(message)"

        logger.info("\(logMessage)")
        appendToFile(logMessage)
    }

    /// Логирует критическую ошибку перед возможным крашем
    public func logCritical(_ message: String, context: String = "") {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] CRITICAL in \(context): \(message)"

        logger.critical("\(logMessage)")
        appendToFile(logMessage)

        // Принудительно синхронизируем запись
        try? FileManager.default.contents(atPath: logFileURL.path)?.write(to: logFileURL)
    }

    private func appendToFile(_ message: String) {
        guard let data = (message + "\n").data(using: .utf8) else { return }

        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            fileHandle.closeFile()
        } else {
            try? data.write(to: logFileURL)
        }
    }

    /// Получить URL файла лога
    public func getLogFileURL() -> URL {
        return logFileURL
    }

    /// Очистить лог файл
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