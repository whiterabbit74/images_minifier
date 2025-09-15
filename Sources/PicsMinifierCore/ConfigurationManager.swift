import Foundation

/// Centralized configuration manager with platform detection and fallbacks
public final class ConfigurationManager {
    public static let shared = ConfigurationManager()

    // MARK: - Platform Detection

    public enum Platform {
        case macOSAppleSilicon
        case macOSIntel
        case unknown
    }

    public var currentPlatform: Platform {
        #if arch(arm64)
        return .macOSAppleSilicon
        #elseif arch(x86_64)
        return .macOSIntel
        #else
        return .unknown
        #endif
    }

    // MARK: - Tool Path Configuration

    private let toolPaths: [Platform: [String: [String]]] = [
        .macOSAppleSilicon: [
            "jpegoptim": ["/opt/homebrew/bin/jpegoptim", "/usr/local/bin/jpegoptim", "/usr/bin/jpegoptim"],
            "oxipng": ["/opt/homebrew/bin/oxipng", "/usr/local/bin/oxipng", "/usr/bin/oxipng"],
            "cwebp": ["/opt/homebrew/bin/cwebp", "/usr/local/bin/cwebp", "/usr/bin/cwebp"],
            "gifsicle": ["/opt/homebrew/bin/gifsicle", "/usr/local/bin/gifsicle", "/usr/bin/gifsicle"],
            "magick": ["/opt/homebrew/bin/magick", "/usr/local/bin/magick", "/usr/bin/magick"]
        ],
        .macOSIntel: [
            "jpegoptim": ["/usr/local/bin/jpegoptim", "/opt/homebrew/bin/jpegoptim", "/usr/bin/jpegoptim"],
            "oxipng": ["/usr/local/bin/oxipng", "/opt/homebrew/bin/oxipng", "/usr/bin/oxipng"],
            "cwebp": ["/usr/local/bin/cwebp", "/opt/homebrew/bin/cwebp", "/usr/bin/cwebp"],
            "gifsicle": ["/usr/local/bin/gifsicle", "/opt/homebrew/bin/gifsicle", "/usr/bin/gifsicle"],
            "magick": ["/usr/local/bin/magick", "/opt/homebrew/bin/magick", "/usr/bin/magick"]
        ],
        .unknown: [
            "jpegoptim": ["/usr/bin/jpegoptim", "/usr/local/bin/jpegoptim"],
            "oxipng": ["/usr/bin/oxipng", "/usr/local/bin/oxipng"],
            "cwebp": ["/usr/bin/cwebp", "/usr/local/bin/cwebp"],
            "gifsicle": ["/usr/bin/gifsicle", "/usr/local/bin/gifsicle"],
            "magick": ["/usr/bin/magick", "/usr/local/bin/magick"]
        ]
    ]

    // MARK: - Tool Discovery

    public func locateTool(_ toolName: String) -> URL? {
        // Check environment override first
        if let envPath = ProcessInfo.processInfo.environment["PICS_\(toolName.uppercased())_PATH"] {
            let url = URL(fileURLWithPath: envPath)
            if validateTool(at: url) {
                return url
            }
        }

        // Check platform-specific paths
        guard let paths = toolPaths[currentPlatform]?[toolName] else {
            return nil
        }

        for path in paths {
            let url = URL(fileURLWithPath: path)
            if validateTool(at: url) {
                return url
            }
        }

        // Fallback: check PATH environment
        return searchInPATH(toolName: toolName)
    }

    private func validateTool(at url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.path) && fm.isExecutableFile(atPath: url.path)
    }

    private func searchInPATH(toolName: String) -> URL? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else {
            return nil
        }

        let pathComponents = pathEnv.components(separatedBy: ":")
        for pathComponent in pathComponents {
            let toolPath = "\(pathComponent)/\(toolName)"
            let url = URL(fileURLWithPath: toolPath)
            if validateTool(at: url) {
                return url
            }
        }

        return nil
    }

    // MARK: - Application Configuration

    public struct AppConfiguration {
        // File size limits
        public let maxFileSize: Int64
        public let maxBatchSize: Int
        public let maxConcurrentOperations: Int

        // Timeouts
        public let processTimeout: TimeInterval
        public let networkTimeout: TimeInterval

        // Memory limits
        public let maxMemoryUsage: UInt64
        public let memoryPressureThreshold: Double

        // Quality settings
        public let defaultQualitySettings: [CompressionPreset: QualitySettings]

        // Paths
        public let tempDirectoryPrefix: String
        public let logDirectory: URL
        public let configDirectory: URL

        public static let `default` = AppConfiguration(
            maxFileSize: 500 * 1024 * 1024, // 500MB
            maxBatchSize: 1000,
            maxConcurrentOperations: max(2, ProcessInfo.processInfo.processorCount - 1),
            processTimeout: 120.0,
            networkTimeout: 30.0,
            maxMemoryUsage: 2 * 1024 * 1024 * 1024, // 2GB
            memoryPressureThreshold: 0.8,
            defaultQualitySettings: [
                .quality: QualitySettings(jpeg: 95, webp: 95, png: 9),
                .balanced: QualitySettings(jpeg: 85, webp: 85, png: 6),
                .saving: QualitySettings(jpeg: 75, webp: 75, png: 4),
                .auto: QualitySettings(jpeg: 85, webp: 85, png: 6)
            ],
            tempDirectoryPrefix: "com.picsminifier",
            logDirectory: AppPaths.logDirectory(),
            configDirectory: AppPaths.configDirectory()
        )
    }

    public struct QualitySettings {
        public let jpeg: Int
        public let webp: Int
        public let png: Int

        public init(jpeg: Int, webp: Int, png: Int) {
            self.jpeg = max(1, min(100, jpeg))
            self.webp = max(1, min(100, webp))
            self.png = max(1, min(9, png))
        }
    }

    private var _configuration = AppConfiguration.default
    public var configuration: AppConfiguration {
        return _configuration
    }

    // MARK: - Tool Availability Check

    public struct ToolAvailability {
        public let jpegoptim: Bool
        public let oxipng: Bool
        public let cwebp: Bool
        public let gifsicle: Bool
        public let magick: Bool

        public var hasModernTools: Bool {
            return jpegoptim && oxipng && cwebp && gifsicle
        }

        public var missingTools: [String] {
            var missing: [String] = []
            if !jpegoptim { missing.append("jpegoptim") }
            if !oxipng { missing.append("oxipng") }
            if !cwebp { missing.append("cwebp") }
            if !gifsicle { missing.append("gifsicle") }
            return missing
        }
    }

    public func checkToolAvailability() -> ToolAvailability {
        return ToolAvailability(
            jpegoptim: locateTool("jpegoptim") != nil,
            oxipng: locateTool("oxipng") != nil,
            cwebp: locateTool("cwebp") != nil,
            gifsicle: locateTool("gifsicle") != nil,
            magick: locateTool("magick") != nil
        )
    }

    // MARK: - Installation Guidance

    public func getInstallationInstructions() -> [String] {
        let availability = checkToolAvailability()
        var instructions: [String] = []

        if !availability.hasModernTools {
            instructions.append("Missing compression tools detected!")
            instructions.append("")

            switch currentPlatform {
            case .macOSAppleSilicon, .macOSIntel:
                instructions.append("Install missing tools using Homebrew:")
                instructions.append("")

                if !availability.jpegoptim {
                    instructions.append("brew install jpegoptim")
                }
                if !availability.oxipng {
                    instructions.append("brew install oxipng")
                }
                if !availability.cwebp {
                    instructions.append("brew install webp")
                }
                if !availability.gifsicle {
                    instructions.append("brew install gifsicle")
                }

            case .unknown:
                instructions.append("Install using your system package manager:")
                instructions.append("- jpegoptim: JPEG optimization tool")
                instructions.append("- oxipng: PNG optimization tool")
                instructions.append("- webp: WebP tools (includes cwebp)")
                instructions.append("- gifsicle: GIF optimization tool")
            }

            instructions.append("")
            instructions.append("After installation, restart the application.")
        } else {
            instructions.append("All compression tools are available! 🎉")
        }

        return instructions
    }

    // MARK: - Configuration Validation

    public func validateConfiguration() -> [String] {
        var issues: [String] = []

        // Check write permissions for temp directory
        let tempDir = FileManager.default.temporaryDirectory
        if !FileManager.default.isWritableFile(atPath: tempDir.path) {
            issues.append("Temporary directory is not writable: \(tempDir.path)")
        }

        // Check log directory permissions
        let logDir = configuration.logDirectory
        do {
            try FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
            if !FileManager.default.isWritableFile(atPath: logDir.path) {
                issues.append("Log directory is not writable: \(logDir.path)")
            }
        } catch {
            issues.append("Cannot create log directory: \(error)")
        }

        // Check available disk space
        do {
            let resourceValues = try tempDir.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            if let availableBytes = resourceValues.volumeAvailableCapacity {
                let minRequired = Int64(1024 * 1024 * 1024) // 1GB
                if availableBytes < minRequired {
                    issues.append("Low disk space: only \(availableBytes / 1024 / 1024)MB available")
                }
            }
        } catch {
            issues.append("Cannot check disk space: \(error)")
        }

        // Check memory constraints
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        if configuration.maxMemoryUsage > physicalMemory {
            issues.append("Memory limit (\(configuration.maxMemoryUsage / 1024 / 1024)MB) exceeds physical RAM (\(physicalMemory / 1024 / 1024)MB)")
        }

        return issues
    }

    // MARK: - Dynamic Configuration Updates

    public func updateConfiguration(_ newConfig: AppConfiguration) {
        _configuration = newConfig

        // Validate the new configuration
        let issues = validateConfiguration()
        if !issues.isEmpty {
            print("Configuration validation warnings:")
            for issue in issues {
                print("  - \(issue)")
            }
        }

        // Post notification about configuration change
        NotificationCenter.default.post(name: .configurationDidChange, object: self)
    }

    // MARK: - Localization Support

    public var supportedLocales: [String] {
        return ["ru", "en"] // Russian and English
    }

    public var defaultLocale: String {
        // Detect system locale and provide fallback
        let systemLocale = Locale.current.languageCode ?? "en"
        return supportedLocales.contains(systemLocale) ? systemLocale : "en"
    }

    private init() {
        // Perform initial validation
        let issues = validateConfiguration()
        if !issues.isEmpty {
            print("Initial configuration issues detected:")
            for issue in issues {
                print("  - \(issue)")
            }
        }
    }
}

// MARK: - Enhanced AppPaths

extension AppPaths {
    public static func configDirectory() -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("PicsMinifier/Config")
        try? fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        return configDir
    }

    public static func logDirectory() -> URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let logDir = appSupport.appendingPathComponent("PicsMinifier/Logs")
        try? fm.createDirectory(at: logDir, withIntermediateDirectories: true)
        return logDir
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let configurationDidChange = Notification.Name("configurationDidChange")
    static let toolAvailabilityChanged = Notification.Name("toolAvailabilityChanged")
}