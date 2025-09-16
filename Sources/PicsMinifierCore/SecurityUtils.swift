import Foundation
import CryptoKit

/// Utility class for security-related operations
public final class SecurityUtils {

    // MARK: - Path Validation

    /// Validates file path to prevent directory traversal attacks
    public static func validateFilePath(_ path: String) throws -> String {
        let normalizedPath = (path as NSString).standardizingPath

        // Check for directory traversal patterns
        if normalizedPath.contains("../") || normalizedPath.contains("..\\") {
            throw SecurityError.pathTraversal
        }

        // Ensure path doesn't escape allowed directories
        let allowedPrefixes = [
            NSTemporaryDirectory(),
            NSHomeDirectory(),
            "/Users",
            "/tmp"
        ]

        let isAllowed = allowedPrefixes.contains { prefix in
            normalizedPath.hasPrefix(prefix)
        }

        if !isAllowed {
            throw SecurityError.unauthorizedPath
        }

        return normalizedPath
    }

    /// Sanitizes filename to prevent path traversal and other security issues
    public static func sanitizeFilename(_ filename: String) -> String {
        var sanitized = filename

        // Remove path separators
        sanitized = sanitized.replacingOccurrences(of: "/", with: "_")
        sanitized = sanitized.replacingOccurrences(of: "\\", with: "_")

        // Remove directory traversal sequences
        sanitized = sanitized.replacingOccurrences(of: "..", with: "")

        // Remove control characters
        sanitized = sanitized.filter { char in
            if let ascii = char.asciiValue {
                return ascii >= 32 && ascii < 127 // Printable ASCII range
            }
            return !char.isASCII // Keep non-ASCII characters
        }

        // Remove other dangerous characters
        let dangerousChars = CharacterSet(charactersIn: "<>:\"|?*")
        sanitized = sanitized.components(separatedBy: dangerousChars).joined(separator: "_")

        // Ensure not empty and not too long
        if sanitized.isEmpty {
            sanitized = "unnamed"
        }

        if sanitized.count > 255 {
            sanitized = String(sanitized.prefix(255))
        }

        return sanitized
    }

    /// Validates and sanitizes command line arguments
    public static func sanitizeProcessArguments(_ arguments: [String]) throws -> [String] {
        var sanitized: [String] = []

        for arg in arguments {
            // Remove potentially dangerous characters
            let dangerous = ["&", "|", ";", "`", "$", "(", ")", "{", "}", "[", "]", "\"", "'", "\\"]
            var safe = arg

            for char in dangerous {
                if safe.contains(char) {
                    throw SecurityError.unsafeArgument(arg)
                }
            }

            // Validate file paths in arguments
            if safe.hasPrefix("/") || safe.hasPrefix("~/") {
                safe = try validateFilePath(safe)
            }

            sanitized.append(safe)
        }

        return sanitized
    }

    // MARK: - Secure Temporary Files

    /// Creates cryptographically secure temporary file name
    public static func createSecureTempFileName(fileExtension: String = "") -> String {
        let randomBytes = SymmetricKey(size: .bits256)
        let hash = SHA256.hash(data: randomBytes.withUnsafeBytes { Data($0) })
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        return fileExtension.isEmpty ? hashString : "\(hashString).\(fileExtension)"
    }

    /// Creates secure temporary directory with proper permissions
    public static func createSecureTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let secureName = createSecureTempFileName()
        let secureDir = tempDir.appendingPathComponent("pics-\(secureName)")

        try FileManager.default.createDirectory(
            at: secureDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700] // Only owner can access
        )

        return secureDir
    }

    // MARK: - Process Execution Security

    /// Secure process execution with timeout and resource limits
    public static func executeSecureProcess(
        executable: URL,
        arguments: [String],
        timeout: TimeInterval = 30.0,
        maxOutputSize: Int = 1024 * 1024 // 1MB
    ) async throws -> SecurityUtils.SecureProcessResult {

        // Validate executable path
        let executablePath = try validateFilePath(executable.path)
        let validatedArgs = try sanitizeProcessArguments(arguments)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = validatedArgs

        // Create isolated environment
        var environment = ProcessInfo.processInfo.environment
        // Remove potentially sensitive environment variables
        let sensitiveKeys = ["DYLD_", "LIBRARY_PATH", "PATH", "HOME"]
        for key in environment.keys {
            for sensitive in sensitiveKeys {
                if key.hasPrefix(sensitive) {
                    environment.removeValue(forKey: key)
                }
            }
        }
        process.environment = environment

        // Set up pipes with size limits
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Start process
        try process.run()

        // Implement timeout
        let processTask = Task {
            process.waitUntilExit()
            return process.terminationStatus
        }

        let terminationStatus: Int32
        do {
            terminationStatus = try await withThrowingTaskGroup(of: Int32.self) { group in
                group.addTask { await processTask.value }
                group.addTask {
                    if #available(macOS 13.0, *) {
                        try await Task.sleep(for: .seconds(timeout))
                    } else {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    }
                    throw SecurityError.processTimeout
                }

                let result = try await group.next()!
                group.cancelAll()
                return result
            }
        } catch {
            process.terminate()
            throw error
        }

        // Read output with size limits
        let stdoutData = stdoutPipe.fileHandleForReading.readData(ofLength: maxOutputSize)
        let stderrData = stderrPipe.fileHandleForReading.readData(ofLength: maxOutputSize)

        return SecurityUtils.SecureProcessResult(
            terminationStatus: terminationStatus,
            stdout: String(data: stdoutData, encoding: .utf8) ?? "",
            stderr: String(data: stderrData, encoding: .utf8) ?? ""
        )
    }

    // MARK: - File Operations Security

    /// Atomic file write operation
    public static func atomicWrite(data: Data, to url: URL) throws {
        let tempURL = url.appendingPathExtension("tmp-\(createSecureTempFileName())")

        try data.write(to: tempURL)

        // Atomic move
        _ = try FileManager.default.replaceItem(at: url, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: nil)
    }

    /// Secure file copy with validation
    public static func secureCopy(from source: URL, to destination: URL) throws {
        let sourcePath = try validateFilePath(source.path)
        let destPath = try validateFilePath(destination.path)

        // Check if source exists and is readable
        guard FileManager.default.isReadableFile(atPath: sourcePath) else {
            throw SecurityError.unreadableFile
        }

        // Ensure destination directory exists
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: destPath).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: sourcePath),
            to: URL(fileURLWithPath: destPath)
        )
    }

    // MARK: - Synchronous Process Execution

    /// Synchronous version of executeSecureProcess for non-async contexts
    public static func executeSecureProcessSync(
        executable: URL,
        arguments: [String],
        timeout: TimeInterval = 30.0,
        maxOutputSize: Int = 1024 * 1024
    ) throws -> SecureProcessResult {
        // Validate executable
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw SecurityError.invalidExecutable
        }

        // Sanitize arguments
        let safeArguments = try sanitizeProcessArguments(arguments)

        let process = Process()
        process.executableURL = executable
        process.arguments = safeArguments

        // Create pipes for output capture
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Set minimal environment
        process.environment = [
            "PATH": "/usr/bin:/bin",
            "HOME": NSTemporaryDirectory()
        ]

        var didTimeout = false
        let semaphore = DispatchSemaphore(value: 0)

        // Start process
        try process.run()

        // Set up timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if process.isRunning {
                didTimeout = true
                process.terminate()
                semaphore.signal()
            }
        }

        // Wait for completion
        process.waitUntilExit()
        semaphore.signal()

        if didTimeout {
            throw SecurityError.processTimeout
        }

        // Read output with size limits
        let stdoutData = stdoutPipe.fileHandleForReading.readData(ofLength: maxOutputSize)
        let stderrData = stderrPipe.fileHandleForReading.readData(ofLength: maxOutputSize)

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return SecureProcessResult(
            terminationStatus: process.terminationStatus,
            stdout: stdout,
            stderr: stderr
        )
    }

    // MARK: - Process Result

    public struct SecureProcessResult {
        public let terminationStatus: Int32
        public let stdout: String
        public let stderr: String

        public var isSuccess: Bool {
            return terminationStatus == 0
        }
    }
}

// MARK: - Security Errors

public enum SecurityError: Error, LocalizedError {
    case pathTraversal
    case unauthorizedPath
    case unsafeArgument(String)
    case processTimeout
    case unreadableFile
    case invalidExecutable

    public var errorDescription: String? {
        switch self {
        case .pathTraversal:
            return "Path contains directory traversal sequences"
        case .unauthorizedPath:
            return "Access to this path is not authorized"
        case .unsafeArgument(let arg):
            return "Unsafe argument detected: \(arg)"
        case .processTimeout:
            return "Process execution timed out"
        case .unreadableFile:
            return "File is not readable"
        case .invalidExecutable:
            return "Executable is not valid or not found"
        }
    }
}