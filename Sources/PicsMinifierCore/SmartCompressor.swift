import Foundation

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

// Legacy fallback service
fileprivate let legacyService = CompressionService()

public final class SmartCompressor {
    public init() {}

    private struct CompressionTools {
        // Configuration-based tool discovery with fallbacks
        static func findTool(name: String) -> String? {
            // Check environment variable first
            let envCandidates = [
                "\(name.uppercased())_PATH",
                "PICS_\(name.uppercased())_PATH"
            ]

            for key in envCandidates {
                if let envPath = ProcessInfo.processInfo.environment[key],
                   FileManager.default.isExecutableFile(atPath: envPath) {
                    return envPath
                }
            }

            // Common installation paths
            let candidates = [
                "/opt/homebrew/bin/\(name)",           // ARM64 Homebrew
                "/usr/local/bin/\(name)",              // Intel Homebrew
                "/opt/local/bin/\(name)",              // MacPorts
                "/usr/bin/\(name)",                    // System
                "/opt/homebrew/opt/mozjpeg/bin/\(name)",
                "/usr/local/opt/mozjpeg/bin/\(name)"
            ]

            return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
                ?? Self.findInPATH(name: name)
        }

        private static func findInPATH(name: String) -> String? {
            guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
            let fm = FileManager.default

            for directory in pathEnv.split(separator: ":") {
                let potential = String(directory).appending("/\(name)")
                if fm.isExecutableFile(atPath: potential) {
                    return potential
                }
            }
            return nil
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

        guard let toolPath = CompressionTools.mozjpegPath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let quality = qualityFor(settings.preset)
        let qualityValue = Int(quality * 100)
        let fileManager = FileManager.default
        let overwritingSource = inputURL.path == outputURL.path

        let destinationURL: URL
        if overwritingSource {
            let tempName = SecurityUtils.createSecureTempFileName(extension: inputURL.pathExtension.isEmpty ? "jpg" : inputURL.pathExtension)
            destinationURL = fileManager.temporaryDirectory.appendingPathComponent(tempName)
        } else {
            destinationURL = outputURL
            try? fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        let arguments = [
            "-quality", "\(qualityValue)",
            "-optimize",
            "-progressive",
            "-outfile", destinationURL.path,
            inputURL.path
        ]

        do {
            let result = try SecurityUtils.executeSecureProcessSync(
                executable: URL(fileURLWithPath: toolPath),
                arguments: arguments,
                timeout: 30.0,
                maxOutputSize: 1024 * 1024
            )

            if result.terminationStatus == 0 {
                let producedSize = (try? fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize

                if producedSize >= originalSize {
                    if destinationURL != inputURL {
                        do {
                            if fileManager.fileExists(atPath: destinationURL.path) {
                                try fileManager.removeItem(at: destinationURL)
                            }
                            try fileManager.copyItem(at: inputURL, to: destinationURL)
                        } catch {
                            return ProcessResult(
                                sourceFormat: "jpeg",
                                targetFormat: "jpeg",
                                originalPath: inputURL.path,
                                outputPath: outputURL.path,
                                originalSizeBytes: originalSize,
                                newSizeBytes: originalSize,
                                status: "error",
                                reason: "copy-original-failed"
                            )
                        }
                    } else {
                        try? fileManager.removeItem(at: destinationURL)
                    }

                    let finalOutputURL = overwritingSource ? inputURL : outputURL
                    return ProcessResult(
                        sourceFormat: "jpeg",
                        targetFormat: "jpeg",
                        originalPath: inputURL.path,
                        outputPath: finalOutputURL.path,
                        originalSizeBytes: originalSize,
                        newSizeBytes: originalSize,
                        status: "success",
                        reason: "no-gain"
                    )
                }

                let finalOutputURL: URL
                if overwritingSource {
                    do {
                        if fileManager.fileExists(atPath: inputURL.path) {
                            try fileManager.removeItem(at: inputURL)
                        }
                        try fileManager.moveItem(at: destinationURL, to: inputURL)
                        finalOutputURL = inputURL
                    } catch {
                        try? fileManager.removeItem(at: destinationURL)
                        return legacyService.compressFile(at: inputURL, settings: settings)
                    }
                } else {
                    finalOutputURL = outputURL
                }

                return ProcessResult(
                    sourceFormat: "jpeg",
                    targetFormat: "jpeg",
                    originalPath: inputURL.path,
                    outputPath: finalOutputURL.path,
                    originalSizeBytes: originalSize,
                    newSizeBytes: producedSize,
                    status: "success",
                    reason: "mozjpeg-compression"
                )
            }
        } catch {
            if overwritingSource {
                try? fileManager.removeItem(at: destinationURL)
            }
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        if overwritingSource {
            try? fileManager.removeItem(at: destinationURL)
        }

        return legacyService.compressFile(at: inputURL, settings: settings)
    }

    private func compressPNGWithOxipng(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) -> ProcessResult {
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

        guard let toolPath = CompressionTools.oxipngPath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let level = levelFor(settings.preset)
        let fileManager = FileManager.default
        let overwritingSource = inputURL.path == outputURL.path

        let destinationURL: URL
        if overwritingSource {
            let tempName = SecurityUtils.createSecureTempFileName(extension: inputURL.pathExtension.isEmpty ? "png" : inputURL.pathExtension)
            destinationURL = fileManager.temporaryDirectory.appendingPathComponent(tempName)
        } else {
            destinationURL = outputURL
            try? fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        let arguments = [
            "--opt", "\(level)",
            "--strip", "safe",
            "--out", destinationURL.path,
            inputURL.path
        ]

        do {
            let result = try SecurityUtils.executeSecureProcessSync(
                executable: URL(fileURLWithPath: toolPath),
                arguments: arguments,
                timeout: 60.0,
                maxOutputSize: 1024 * 1024
            )

            if result.terminationStatus == 0 {
                let producedSize = (try? fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize

                if producedSize >= originalSize {
                    if destinationURL != inputURL {
                        do {
                            if fileManager.fileExists(atPath: destinationURL.path) {
                                try fileManager.removeItem(at: destinationURL)
                            }
                            try fileManager.copyItem(at: inputURL, to: destinationURL)
                        } catch {
                            return ProcessResult(
                                sourceFormat: "png",
                                targetFormat: "png",
                                originalPath: inputURL.path,
                                outputPath: outputURL.path,
                                originalSizeBytes: originalSize,
                                newSizeBytes: originalSize,
                                status: "error",
                                reason: "copy-original-failed"
                            )
                        }
                    } else {
                        try? fileManager.removeItem(at: destinationURL)
                    }

                    let finalOutputURL = overwritingSource ? inputURL : outputURL
                    return ProcessResult(
                        sourceFormat: "png",
                        targetFormat: "png",
                        originalPath: inputURL.path,
                        outputPath: finalOutputURL.path,
                        originalSizeBytes: originalSize,
                        newSizeBytes: originalSize,
                        status: "success",
                        reason: "no-gain"
                    )
                }

                let finalOutputURL: URL
                if overwritingSource {
                    do {
                        if fileManager.fileExists(atPath: inputURL.path) {
                            try fileManager.removeItem(at: inputURL)
                        }
                        try fileManager.moveItem(at: destinationURL, to: inputURL)
                        finalOutputURL = inputURL
                    } catch {
                        try? fileManager.removeItem(at: destinationURL)
                        return legacyService.compressFile(at: inputURL, settings: settings)
                    }
                } else {
                    finalOutputURL = outputURL
                }

                return ProcessResult(
                    sourceFormat: "png",
                    targetFormat: "png",
                    originalPath: inputURL.path,
                    outputPath: finalOutputURL.path,
                    originalSizeBytes: originalSize,
                    newSizeBytes: producedSize,
                    status: "success",
                    reason: "oxipng-compression"
                )
            }
        } catch {
            if overwritingSource {
                try? fileManager.removeItem(at: destinationURL)
            }
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        if overwritingSource {
            try? fileManager.removeItem(at: destinationURL)
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
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let level = levelFor(settings.preset)
        let overwriteSameFile = inputURL.path == outputURL.path
        let fm = FileManager.default

        let tempOutputURL: URL
        if overwriteSameFile {
            let tempName = SecurityUtils.createSecureTempFileName(extension: "gif")
            tempOutputURL = fm.temporaryDirectory.appendingPathComponent(tempName)
        } else {
            tempOutputURL = outputURL
        }

        try? fm.createDirectory(at: tempOutputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let arguments = [
            "--optimize=\(level)",
            "--output", tempOutputURL.path,
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
                let producedSize = (try? fm.attributesOfItem(atPath: tempOutputURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize

                if producedSize >= originalSize {
                    if overwriteSameFile {
                        try? fm.removeItem(at: tempOutputURL)
                    } else {
                        do {
                            if fm.fileExists(atPath: tempOutputURL.path) {
                                try fm.removeItem(at: tempOutputURL)
                            }
                            try fm.copyItem(at: inputURL, to: outputURL)
                        } catch {
                            return ProcessResult(
                                sourceFormat: "gif",
                                targetFormat: "gif",
                                originalPath: inputURL.path,
                                outputPath: outputURL.path,
                                originalSizeBytes: originalSize,
                                newSizeBytes: originalSize,
                                status: "error",
                                reason: "copy-original-failed"
                            )
                        }
                    }

                    let finalOutputURL = overwriteSameFile ? inputURL : outputURL
                    return ProcessResult(
                        sourceFormat: "gif",
                        targetFormat: "gif",
                        originalPath: inputURL.path,
                        outputPath: finalOutputURL.path,
                        originalSizeBytes: originalSize,
                        newSizeBytes: originalSize,
                        status: "success",
                        reason: "no-gain"
                    )
                }

                let finalOutputURL: URL

                if overwriteSameFile {
                    do {
                        if fm.fileExists(atPath: inputURL.path) {
                            try fm.removeItem(at: inputURL)
                        }
                        try fm.moveItem(at: tempOutputURL, to: inputURL)
                        finalOutputURL = inputURL
                    } catch {
                        try? fm.removeItem(at: tempOutputURL)
                        return legacyService.compressFile(at: inputURL, settings: settings)
                    }
                } else {
                    finalOutputURL = outputURL
                }

                return ProcessResult(
                    sourceFormat: "gif",
                    targetFormat: "gif",
                    originalPath: inputURL.path,
                    outputPath: finalOutputURL.path,
                    originalSizeBytes: originalSize,
                    newSizeBytes: producedSize,
                    status: "success",
                    reason: "gifsicle-compression"
                )
            }
        } catch {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        if overwriteSameFile {
            try? FileManager.default.removeItem(at: tempOutputURL)
        }

        return legacyService.compressFile(at: inputURL, settings: settings)
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

            if sanitizedExt.isEmpty {
                return dir.appendingPathComponent("\(sanitizedName)_compressed")
            } else {
                return dir.appendingPathComponent("\(sanitizedName)_compressed.\(sanitizedExt)")
            }
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
#else

public final class SmartCompressor {
    public init() {}

    public func compressFile(at inputURL: URL, settings: AppSettings) -> ProcessResult {
        return CompressionService().compressFile(at: inputURL, settings: settings)
    }
}

#endif
