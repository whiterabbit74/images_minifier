import Foundation

public final class CSVLogger {
    private static let headerLine = "timestamp,sourceFormat,targetFormat,originalPath,outputPath,originalSizeBytes,newSizeBytes,bytesSaved,savedRatio,status,reason\n"

    private let logURL: URL
    private let queue = DispatchQueue(label: "com.picsminifier.csvlogger", qos: .utility)
    private let dateFormatter: ISO8601DateFormatter

    public init?(logURL: URL) {
        self.logURL = logURL
        self.dateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        let directory = logURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            if !FileManager.default.fileExists(atPath: logURL.path) {
                try Self.headerLine.write(to: logURL, atomically: true, encoding: .utf8)
            } else {
                try ensureHeaderExists()
            }
        } catch {
            return nil
        }
    }

    public func append(_ record: ProcessResult) {
        queue.async {
            let line = self.composeLine(from: record)
            guard let data = line.data(using: .utf8) else { return }

            do {
                if !FileManager.default.fileExists(atPath: self.logURL.path) {
                    try Self.headerLine.write(to: self.logURL, atomically: true, encoding: .utf8)
                }

                let fileHandle = try FileHandle(forWritingTo: self.logURL)
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
            } catch {
                // Fallback: rewrite the entire file atomically to avoid losing data
                let existingData = (try? Data(contentsOf: self.logURL)) ?? Data()
                let combined = existingData + data
                try? combined.write(to: self.logURL, options: .atomic)
            }
        }
    }

    // MARK: - Helpers

    private func ensureHeaderExists() throws {
        let content = try String(contentsOf: logURL, encoding: .utf8)
        if content.isEmpty {
            try Self.headerLine.write(to: logURL, atomically: true, encoding: .utf8)
            return
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first, first == Self.headerLine.trimmingCharacters(in: .newlines) else {
            var remainder = content
            if !remainder.hasSuffix("\n") {
                remainder.append("\n")
            }
            let updated = Self.headerLine + remainder
            try updated.write(to: logURL, atomically: true, encoding: .utf8)
            return
        }
    }

    private func composeLine(from result: ProcessResult) -> String {
        let timestamp = dateFormatter.string(from: Date())
        let savedBytes = max(0, result.originalSizeBytes - result.newSizeBytes)
        let ratio: Double
        if result.originalSizeBytes > 0 {
            ratio = Double(savedBytes) / Double(result.originalSizeBytes)
        } else {
            ratio = 0
        }

        let savedRatio = String(format: "%.6f", ratio)

        let fields: [String] = [
            timestamp,
            csvEscape(result.sourceFormat),
            csvEscape(result.targetFormat),
            csvEscape(result.originalPath),
            csvEscape(result.outputPath),
            String(result.originalSizeBytes),
            String(result.newSizeBytes),
            String(savedBytes),
            savedRatio,
            csvEscape(result.status),
            csvEscape(result.reason ?? "")
        ]

        return fields.joined(separator: ",") + "\n"
    }

    private func csvEscape(_ field: String) -> String {
        guard field.contains("\"") || field.contains(",") || field.contains("\n") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
