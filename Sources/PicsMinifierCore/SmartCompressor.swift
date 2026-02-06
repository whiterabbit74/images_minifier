import Foundation

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

// Legacy fallback service
fileprivate let legacyService = CompressionService()

public final class SmartCompressor {
    public init() {}

    // Use centralized configuration for tool discovery
    private var mozjpegPath: String? { ConfigurationManager.shared.locateTool("cjpeg")?.path }
    private var cjpegliPath: String? { ConfigurationManager.shared.locateTool("cjpegli")?.path }
    private var oxipngPath: String? { ConfigurationManager.shared.locateTool("oxipng")?.path }
    private var gifsiclePath: String? { ConfigurationManager.shared.locateTool("gifsicle")?.path }
    private var avifencPath: String? { ConfigurationManager.shared.locateTool("avifenc")?.path }

    public func compressFile(at inputURL: URL, settings: AppSettings) async -> ProcessResult {
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
            return await compressJPEGWithMozJPEG(inputURL: inputURL, outputURL: outputURL, settings: settings, originalSize: originalSize)
        } else if utType.conforms(to: .png) {
            return await compressPNGWithOxipng(inputURL: inputURL, outputURL: outputURL, settings: settings, originalSize: originalSize)
        } else if sourceFormat == "gif" {
            return await compressGIFWithGifsicle(inputURL: inputURL, outputURL: outputURL, settings: settings, originalSize: originalSize)
        } else if utType.conforms(to: UTType(importedAs: "public.avif")) || sourceFormat == "avif" {
            return await compressAVIFWithAvifenc(inputURL: inputURL, outputURL: outputURL, settings: settings, originalSize: originalSize)
        } else {
            // Fallback to ImageIO for unsupported formats
            return legacyService.compressFile(at: inputURL, settings: settings)
        }
    }

    private func compressAVIFWithAvifenc(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) async -> ProcessResult {
         do {
            let _ = try SecurityUtils.validateFilePath(inputURL.path)
            let _ = try SecurityUtils.validateFilePath(outputURL.path)
        } catch {
            return ProcessResult(
                sourceFormat: "avif",
                targetFormat: "avif",
                originalPath: inputURL.path,
                outputPath: inputURL.path,
                originalSizeBytes: originalSize,
                newSizeBytes: originalSize,
                status: "error",
                reason: "security-validation-failed"
            )
        }

        guard let toolPath = avifencPath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let quality = avifQuality(for: settings)
        let speed = avifSpeed(for: settings)
        let fileManager = FileManager.default
        let overwritingSource = inputURL.path == outputURL.path

        let destinationURL: URL
        if overwritingSource {
            let tempName = SecurityUtils.createSecureTempFileName(extension: inputURL.pathExtension.isEmpty ? "avif" : inputURL.pathExtension)
            destinationURL = fileManager.temporaryDirectory.appendingPathComponent(tempName)
        } else {
            destinationURL = outputURL
            try? fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        let arguments = [
            "--jobs", "all",
            "--min", "0", "--max", "63",
            "-a", "end-usage=q",
            "-a", "cq-level=\(quality)",
            "-a", "tune=ssim",
            "-s", "\(speed)",
            inputURL.path,
            destinationURL.path
        ]

        do {
            let result = try await SecurityUtils.executeSecureProcess(
                executable: URL(fileURLWithPath: toolPath),
                arguments: arguments,
                timeout: 120.0, // AVIF is slow
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
                                sourceFormat: "avif",
                                targetFormat: "avif",
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
                        sourceFormat: "avif",
                        targetFormat: "avif",
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
                    sourceFormat: "avif",
                    targetFormat: "avif",
                    originalPath: inputURL.path,
                    outputPath: finalOutputURL.path,
                    originalSizeBytes: originalSize,
                    newSizeBytes: producedSize,
                    status: "success",
                    reason: "avifenc-compression"
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

    private func compressJPEGWithMozJPEG(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) async -> ProcessResult {
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

        // Prefer cjpegli if available, otherwise fallback to mozjpeg
        let activeToolPath = cjpegliPath ?? mozjpegPath
        let isJpegli = (activeToolPath == cjpegliPath && cjpegliPath != nil)
        
        guard let toolPath = activeToolPath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let quality = qualityFor(settings)
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

        var arguments: [String] = []
        if isJpegli {
             // Jpegli arguments (similar to cjpeg but optimized defaults)
             arguments = [
                "--quality", "\(qualityValue)",
                inputURL.path,
                destinationURL.path
             ]
        } else {
            // MozJPEG arguments
            arguments = [
                "-quality", "\(qualityValue)",
                "-optimize",
                "-progressive",
                "-outfile", destinationURL.path,
                inputURL.path
            ]
        }

        do {
            let result = try await SecurityUtils.executeSecureProcess(
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
                    reason: isJpegli ? "jpegli-compression" : "mozjpeg-compression"
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

    private func compressPNGWithOxipng(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) async -> ProcessResult {
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

        guard let toolPath = oxipngPath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let level = levelFor(settings)
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
            let result = try await SecurityUtils.executeSecureProcess(
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

    private func compressGIFWithGifsicle(inputURL: URL, outputURL: URL, settings: AppSettings, originalSize: Int64) async -> ProcessResult {
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
        guard let toolPath = gifsiclePath else {
            return legacyService.compressFile(at: inputURL, settings: settings)
        }

        let level = levelFor(settings)
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

        var arguments = [
            "--optimize=\(level)"
        ]
        if settings.enableGifLossy {
            arguments.append("--lossy=80")
        }
        arguments.append(contentsOf: [
            "--output", tempOutputURL.path,
            inputURL.path
        ])

        do {
            let result = try await SecurityUtils.executeSecureProcess(
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

    private func qualityFor(_ settings: AppSettings) -> Float {
        switch settings.preset {
        case .custom: return Float(settings.customJpegQuality)
        case .quality: return 0.92
        case .balanced: return 0.82
        case .saving: return 0.72
        }
    }

    private func levelFor(_ settings: AppSettings) -> Int {
        switch settings.preset {
        case .custom: return settings.customPngLevel
        case .quality: return 2
        case .balanced: return 3
        case .saving: return 6
        }
    }

    private func avifQuality(for settings: AppSettings) -> Int {
        switch settings.preset {
        case .custom: return settings.customAvifQuality
        case .quality: return 18
        case .balanced: return 28
        case .saving: return 38
        }
    }

    private func avifSpeed(for settings: AppSettings) -> Int {
        switch settings.preset {
        case .custom: return settings.customAvifSpeed
        case .quality: return 3
        case .balanced: return 4
        case .saving: return 5
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
