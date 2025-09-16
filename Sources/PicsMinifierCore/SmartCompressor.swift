import Foundation
import UniformTypeIdentifiers

// Legacy fallback service
fileprivate let legacyService = CompressionService()

public final class SmartCompressor {
    public init() {}

    private struct CompressionTools {
        // Configuration-based tool discovery with fallbacks
        static func findTool(name: String) -> String? {
            // Check environment variable first
            if let envPath = ProcessInfo.processInfo.environment["\(name.uppercased())_PATH"] {
                if FileManager.default.isExecutableFile(atPath: envPath) {
                    return envPath
                }
            }

            // Common installation paths
            let candidates = [
                "/opt/homebrew/bin/\(name)",           // ARM64 Homebrew
                "/usr/local/bin/\(name)",              // Intel Homebrew
                "/opt/local/bin/\(name)",              // MacPorts
                "/usr/bin/\(name)",                    // System
                "/opt/homebrew/opt/mozjpeg/bin/\(name)" // MozJPEG special case
            ]

            return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
        }

        static var mozjpegPath: String? { findTool(name: "cjpeg") }
        static var oxipngPath: String? { findTool(name: "oxipng") }
        static var gifsicle: String? { findTool(name: "gifsicle") }
        static var avifenc: String? { findTool(name: "avifenc") }
        static var avifdec: String? { findTool(name: "avifdec") }
    }

    public func compressFile(at inputURL: URL, settings: AppSettings) -> ProcessResult {
        // Security: Validate input path first
        do {
            let _ = try SecurityUtils.validateFilePath(inputURL.path)
        } catch {
            return ProcessResult(
                sourceFormat: "unknown",
                targetFormat: "unknown",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: 0,
                newSizeBytes: 0,
                status: "error",
                reason: "invalid-input-path"
            )
        }

        let fm = FileManager.default
        let originalSize = (try? fm.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? 0

        // Security: File size validation to prevent DoS
        let maxFileSize: Int64 = 1024 * 1024 * 1024 // 1GB limit
        if originalSize > maxFileSize {
            return ProcessResult(
                sourceFormat: "oversized",
                targetFormat: "oversized",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "error",
                reason: "file-too-large"
            )
        }

        // Minimum file size check
        if originalSize < 100 {
            return ProcessResult(
                sourceFormat: "tiny",
                targetFormat: "tiny",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "skipped",
                reason: "file-too-small"
            )
        }

        let resVals = try? inputURL.resourceValues(forKeys: [.contentTypeKey])
        let sourceType = resVals?.contentType
        let sourceFormat = sourceType?.preferredFilenameExtension ?? inputURL.pathExtension.lowercased()

        guard let utType = sourceType else {
            return ProcessResult(
                sourceFormat: sourceFormat,
                targetFormat: sourceFormat,
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "skipped",
                reason: "unknown-content-type"
            )
        }

        let outputURL = computeOutputURL(for: inputURL, mode: settings.saveMode)

        // Выбираем лучший движок сжатия по типу файла
        if utType.conforms(to: .jpeg) {
            return compressJPEGWithMozJPEG(inputURL: inputURL, outputURL: outputURL, settings: settings, originalSize: originalSize)
        } else if utType.conforms(to: .png) {
            return compressPNGWithOxipng(inputURL: inputURL, outputURL: outputURL, settings: settings, originalSize: originalSize)
        } else if sourceFormat == "gif" {
            return compressGIFWithGifsicle(inputURL: inputURL, outputURL: outputURL, settings: settings, originalSize: originalSize)
        } else {
            // Fallback to ImageIO for unsupported formats
            return legacyService.compressFile(at: inputURL, settings: settings)
        }
    }

    private func compressJPEGWithMozJPEG(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) -> ProcessResult {
        // Security: Validate paths before processing
        do {
            let _ = try SecurityUtils.validateFilePath(inputURL.path)
            let _ = try SecurityUtils.validateFilePath(outputURL.path)
        } catch {
            return ProcessResult(
                sourceFormat: "jpeg",
                targetFormat: "jpeg",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "error",
                reason: "security-validation-failed"
            )
        }

        // Check tool availability
        guard let toolPath = CompressionTools.mozjpegPath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let quality = qualityFor(settings.preset)
        let qualityValue = Int(quality * 100)

        // Security: Use SecurityUtils for safe process execution
        let arguments = [
            "-quality", "\(qualityValue)",
            "-optimize",
            "-progressive",
            "-outfile", outputURL.path,
            inputURL.path
        ]

        do {
            let result = try SecurityUtils.executeSecureProcessSync(
                executable: URL(fileURLWithPath: toolPath),
                arguments: arguments,
                timeout: 30.0, // 30 second timeout
                maxOutputSize: 1024 * 1024 // 1MB output limit
            )

            if result.terminationStatus == 0 {
                let newSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize
                return ProcessResult(
                    sourceFormat: "jpeg",
                    targetFormat: "jpeg",
                    originalPath: inputURL.path,
                    outputPath: outputURL.path,
                    originalSizeBytes: originalSize,
                    newSizeBytes: newSize,
                    status: "success",
                    reason: "mozjpeg-compression"
                )
            }
        } catch {
            // Fallback to ImageIO if MozJPEG fails
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        return legacyService.compressFile(at: inputURL, settings: settings)
    }

    private func compressPNGWithOxipng(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) -> ProcessResult {
        // Security: Validate paths before processing
        do {
            let _ = try SecurityUtils.validateFilePath(inputURL.path)
            let _ = try SecurityUtils.validateFilePath(outputURL.path)
        } catch {
            return ProcessResult(
                sourceFormat: "png",
                targetFormat: "png",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "error",
                reason: "security-validation-failed"
            )
        }

        // Check tool availability
        guard let toolPath = CompressionTools.oxipngPath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let level = levelFor(settings.preset)
        let arguments = [
            "--opt", "\(level)",
            "--strip", "safe",
            "--out", outputURL.path,
            inputURL.path
        ]

        do {
            let result = try SecurityUtils.executeSecureProcessSync(
                executable: URL(fileURLWithPath: toolPath),
                arguments: arguments,
                timeout: 60.0, // PNG can take longer
                maxOutputSize: 1024 * 1024
            )

            if result.terminationStatus == 0 {
                let newSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize
                return ProcessResult(
                    sourceFormat: "png",
                    targetFormat: "png",
                    originalPath: inputURL.path,
                    outputPath: outputURL.path,
                    originalSizeBytes: originalSize,
                    newSizeBytes: newSize,
                    status: "success",
                    reason: "oxipng-compression"
                )
            }
        } catch {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        return legacyService.compressFile(at: inputURL, settings: settings)
    }

    private func compressGIFWithGifsicle(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) -> ProcessResult {
        // Security: Validate paths before processing
        do {
            let _ = try SecurityUtils.validateFilePath(inputURL.path)
            let _ = try SecurityUtils.validateFilePath(outputURL.path)
        } catch {
            return ProcessResult(
                sourceFormat: "gif",
                targetFormat: "gif",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "error",
                reason: "security-validation-failed"
            )
        }

        // Check tool availability
        guard let toolPath = CompressionTools.gifsicle else {
            return ProcessResult(
                sourceFormat: "gif",
                targetFormat: "gif",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "error",
                reason: "tool-not-available"
            )
        }

        let level = levelFor(settings.preset)
        let arguments = [
            "--optimize=\(level)",
            "--output", outputURL.path,
            inputURL.path
        ]

        do {
            let result = try SecurityUtils.executeSecureProcessSync(
                executable: URL(fileURLWithPath: toolPath),
                arguments: arguments,
                timeout: 45.0, // GIF can take longer
                maxOutputSize: 1024 * 1024
            )

            if result.terminationStatus == 0 {
                let newSize = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize
                return ProcessResult(
                    sourceFormat: "gif",
                    targetFormat: "gif",
                    originalPath: inputURL.path,
                    outputPath: outputURL.path,
                    originalSizeBytes: originalSize,
                    newSizeBytes: newSize,
                    status: "success",
                    reason: "gifsicle-compression"
                )
            }
        } catch {
            return ProcessResult(
                sourceFormat: "gif",
                targetFormat: "gif",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "error",
                reason: "gifsicle-failed"
            )
        }

        return ProcessResult(
            sourceFormat: "gif",
            targetFormat: "gif",
            originalPath: inputURL.path,
            outputPath: inputURL.path,
            originalSizeBytes: originalSize,
            newSizeBytes: originalSize,
            status: "error",
            reason: "gifsicle-failed"
        )
    }

    private func computeOutputURL(for inputURL: URL, mode: SaveMode) -> URL {
        switch mode {
        case .overwrite:
            return inputURL
        case .suffix:
            let ext = inputURL.pathExtension
            let nameWithoutExt = inputURL.deletingPathExtension().lastPathComponent
            let dir = inputURL.deletingLastPathComponent()

            // Security: Sanitize filename to prevent path traversal
            let sanitizedName = SecurityUtils.sanitizeFilename(nameWithoutExt)
            let sanitizedExt = SecurityUtils.sanitizeFilename(ext)

            return dir.appendingPathComponent("\(sanitizedName)_compressed.\(sanitizedExt)")
        case .separateFolder:
            let dir = inputURL.deletingLastPathComponent().appendingPathComponent("compressed")

            // Security: Validate directory creation path
            do {
                let _ = try SecurityUtils.validateFilePath(dir.path)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                // Fallback to same directory if validation fails
                return computeOutputURL(for: inputURL, mode: .suffix)
            }

            // Security: Sanitize filename
            let sanitizedFilename = SecurityUtils.sanitizeFilename(inputURL.lastPathComponent)
            return dir.appendingPathComponent(sanitizedFilename)
        }
    }

    private func qualityFor(_ preset: CompressionPreset) -> Float {
        switch preset {
        case .quality: return 0.92
        case .balanced: return 0.82
        case .saving: return 0.72
        case .auto: return 0.82
        }
    }

    private func levelFor(_ preset: CompressionPreset) -> Int {
        switch preset {
        case .quality: return 2
        case .balanced: return 3
        case .saving: return 6
        case .auto: return 3
        }
    }
}