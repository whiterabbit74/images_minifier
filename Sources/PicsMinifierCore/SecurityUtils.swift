import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Utility class for security-related operations
public final class SecurityUtils {

    // MARK: - Path Validation

    /// Validates file path to prevent directory traversal attacks
    public static func validateFilePath(_ path: String) throws -> String {
        let expandedPath = (path as NSString).expandingTildeInPath
        let inputURL = URL(fileURLWithPath: expandedPath)

        if inputURL.pathComponents.contains("..") {
            throw SecurityError.pathTraversal
        }

        let resolvedURL = inputURL.resolvingSymlinksInPath()
        let normalizedURL = resolvedURL.standardizedFileURL

        var allowedDirectories: [URL] = []
        let fileManager = FileManager.default

        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
        allowedDirectories.append(homeDirectory)

        let userHome = fileManager.homeDirectoryForCurrentUser.standardizedFileURL
        if userHome != homeDirectory {
            allowedDirectories.append(userHome)
        }

        let tmpDirectory = fileManager.temporaryDirectory.standardizedFileURL
        allowedDirectories.append(tmpDirectory)

        let legacyTmp = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL
        if legacyTmp != tmpDirectory {
            allowedDirectories.append(legacyTmp)
        }

        allowedDirectories.append(URL(fileURLWithPath: "/tmp").standardizedFileURL)
        allowedDirectories.append(URL(fileURLWithPath: "/private/tmp").standardizedFileURL)
        allowedDirectories.append(URL(fileURLWithPath: "/Volumes").standardizedFileURL)

        let isAllowed = allowedDirectories.contains { baseURL in
            let basePath = baseURL.path
            let normalizedPath = normalizedURL.path

            if normalizedPath == basePath {
                return true
            }

            let normalizedBase = basePath.hasSuffix("/") ? basePath : basePath + "/"
            return normalizedPath.hasPrefix(normalizedBase)
        }

        if !isAllowed {
            throw SecurityError.unauthorizedPath
        }

        return normalizedURL.path
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
            var safe = arg

            let disallowedCharacters = CharacterSet(charactersIn: "&|;`><")
            if safe.rangeOfCharacter(from: disallowedCharacters) != nil {
                throw SecurityError.unsafeArgument(arg)
            }

            if safe.contains("\0") || safe.contains("\n") || safe.contains("\r") {
                throw SecurityError.unsafeArgument(arg)
            }

            if safe.contains("$(") {
                throw SecurityError.unsafeArgument(arg)
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
    public static func createSecureTempFileName(`extension`: String = "") -> String {
        #if canImport(CryptoKit)
        let randomBytes = SymmetricKey(size: .bits256)
        let hash = SHA256.hash(data: randomBytes.withUnsafeBytes { Data($0) })
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        #else
        let hashString = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        #endif

        return `extension`.isEmpty ? hashString : "\(hashString).\(`extension`)"
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
        let sensitivePrefixes = ["DYLD_", "LD_", "LIBRARY_PATH"]
        for key in environment.keys {
            if sensitivePrefixes.contains(where: { key.hasPrefix($0) }) {
                environment.removeValue(forKey: key)
            }
        }

        if environment["PATH"] == nil {
            environment["PATH"] = "/usr/bin:/bin"
        }

        if environment["HOME"] == nil {
            environment["HOME"] = NSHomeDirectory()
        }

        process.environment = environment

        // Set up pipes with size limits
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        // Start process
        try process.run()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading

        @Sendable func captureOutput(from handle: FileHandle, limit: Int) -> Data {
            var buffer = Data()
            let chunkSize = 4096

            while true {
                let chunk = handle.readData(ofLength: chunkSize)
                if chunk.isEmpty {
                    break
                }

                if buffer.count < limit {
                    let remaining = limit - buffer.count
                    if remaining >= chunk.count {
                        buffer.append(chunk)
                    } else {
                        buffer.append(chunk.prefix(remaining))
                    }
                }
            }

            return buffer
        }

        var stdoutData = Data()
        var stderrData = Data()
        let captureGroup = DispatchGroup()
        let stdoutStorageQueue = DispatchQueue(label: "com.picsminifier.stdout")
        let stderrStorageQueue = DispatchQueue(label: "com.picsminifier.stderr")

        captureGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = captureOutput(from: stdoutHandle, limit: maxOutputSize)
            stdoutStorageQueue.sync { stdoutData = data }
            captureGroup.leave()
        }

        captureGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = captureOutput(from: stderrHandle, limit: maxOutputSize)
            stderrStorageQueue.sync { stderrData = data }
            captureGroup.leave()
        }

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
            stdoutHandle.closeFile()
            stderrHandle.closeFile()
            captureGroup.wait()
            throw error
        }

        captureGroup.wait()
        stdoutHandle.closeFile()
        stderrHandle.closeFile()

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
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
        try fm.moveItem(at: tempURL, to: url)
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

        var environment = ProcessInfo.processInfo.environment
        let sensitivePrefixes = ["DYLD_", "LD_", "LIBRARY_PATH"]
        for key in environment.keys {
            if sensitivePrefixes.contains(where: { key.hasPrefix($0) }) {
                environment.removeValue(forKey: key)
            }
        }

        if environment["PATH"] == nil {
            environment["PATH"] = "/usr/bin:/bin"
        }

        if environment["HOME"] == nil {
            environment["HOME"] = NSHomeDirectory()
        }

        process.environment = environment

        var didTimeout = false
        let semaphore = DispatchSemaphore(value: 0)
        let timeoutStateQueue = DispatchQueue(label: "com.picsminifier.timeoutstate")

        // Start process
        try process.run()

        // Set up timeout
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if process.isRunning {
                timeoutStateQueue.sync { didTimeout = true }
                process.terminate()
                semaphore.signal()
            }
        }

        // Wait for completion
        process.waitUntilExit()
        semaphore.signal()

        if timeoutStateQueue.sync(execute: { didTimeout }) {
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