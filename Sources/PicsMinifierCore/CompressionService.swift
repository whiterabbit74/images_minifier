import Foundation

#if canImport(ImageIO) && canImport(UniformTypeIdentifiers) && canImport(CoreGraphics)
import ImageIO
import UniformTypeIdentifiers
import CoreGraphics

public final class CompressionService {
	public init() {}

	public func compressFile(at inputURL: URL, settings: AppSettings) -> ProcessResult {
		let fm = FileManager.default
		let originalSize = (try? fm.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? 0
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

		// Determine output path (save mode)
		let outputURL = Self.computeOutputURL(for: inputURL, mode: settings.saveMode)

		// Format-based compression without container change
		let result: ProcessResult
		if utType.conforms(to: .jpeg) {
			result = reencodeImageIO(inputURL: inputURL, outputURL: outputURL, destUTType: UTType.jpeg.identifier as CFString, quality: qualityFor(settings), tiffLZW: false, pngLossless: false, preserveMetadata: settings.preserveMetadata, convertToSRGB: settings.convertToSRGB, maxDimension: settings.maxDimension)
		} else if utType.conforms(to: .png) {
			// PNG: lossless attempt via ImageIO (zlib level not publicly available)
			result = reencodeImageIO(inputURL: inputURL, outputURL: outputURL, destUTType: UTType.png.identifier as CFString, quality: nil, tiffLZW: false, pngLossless: true, preserveMetadata: settings.preserveMetadata, convertToSRGB: settings.convertToSRGB, maxDimension: settings.maxDimension)
		} else if utType.conforms(to: .heic) || utType.conforms(to: .heif) {
			let heicUT: CFString = (utType.conforms(to: .heic) ? UTType.heic.identifier : UTType.heif.identifier) as CFString
			result = reencodeImageIO(inputURL: inputURL, outputURL: outputURL, destUTType: heicUT, quality: qualityFor(settings), tiffLZW: false, pngLossless: false, preserveMetadata: settings.preserveMetadata, convertToSRGB: settings.convertToSRGB, maxDimension: settings.maxDimension)
		} else if utType.conforms(to: .tiff) {
			result = reencodeImageIO(inputURL: inputURL, outputURL: outputURL, destUTType: UTType.tiff.identifier as CFString, quality: nil, tiffLZW: true, pngLossless: false, preserveMetadata: settings.preserveMetadata, convertToSRGB: settings.convertToSRGB, maxDimension: settings.maxDimension)
		} else if utType.conforms(to: UTType(importedAs: "org.webmproject.webp")) {
			// WebP: system codec (if available) -> otherwise embedded libwebp (after vendoring)
			let encoder = WebPEncoder()
			switch encoder.availability() {
			case .systemCodec:
				result = reencodeImageIO(
					inputURL: inputURL,
					outputURL: outputURL,
					destUTType: UTType(importedAs: "org.webmproject.webp").identifier as CFString,
					quality: qualityFor(settings),
					tiffLZW: false,
					pngLossless: false,
					preserveMetadata: settings.preserveMetadata,
					convertToSRGB: settings.convertToSRGB,
					maxDimension: settings.maxDimension
				)
			case .embedded:
				result = reencodeWebPWithEmbedded(inputURL: inputURL, outputURL: outputURL, settings: settings, convertToSRGB: settings.convertToSRGB, maxDimension: settings.maxDimension)
			case .unavailable:
				// WebPCliReencoder temporarily disabled
				// if ProcessInfo.processInfo.environment["PICS_FORCE_WEBP_CLI"] == "1" {
				//     let cli = WebPCliReencoder()
				//     let out = (settings.saveMode == .overwrite) ? inputURL : outputURL
				//     result = cli.reencode(inputURL: inputURL, outputURL: out, quality: Int(webPQuality(for: settings.preset)), preserveMetadata: settings.preserveMetadata)
				//     break
				// }
				result = ProcessResult(
					sourceFormat: sourceFormat,
					targetFormat: sourceFormat,
					originalPath: inputURL.path,
					outputPath: inputURL.path,
					originalSizeBytes: originalSize,
					newSizeBytes: originalSize,
					status: "skipped",
					reason: "webp-encoder-unavailable"
				)
			}
		} else if utType.conforms(to: .gif) {
			if settings.enableGifsicle {
				let optimizer = GifsicleOptimizer()
				let out = (settings.saveMode == .overwrite) ? inputURL : outputURL
				result = optimizer.optimize(inputURL: inputURL, outputURL: out, lossy: settings.enableGifLossy)
			} else {
				result = ProcessResult(
					sourceFormat: sourceFormat,
					targetFormat: sourceFormat,
					originalPath: inputURL.path,
					outputPath: inputURL.path,
					originalSizeBytes: originalSize,
					newSizeBytes: originalSize,
					status: "skipped",
					reason: "gifsicle-disabled"
				)
			}
		} else {
			// BMP/TGA etc.: no conversions - skip if compression is unavailable
			result = ProcessResult(
				sourceFormat: sourceFormat,
				targetFormat: sourceFormat,
				originalPath: inputURL.path,
				outputPath: inputURL.path,
				originalSizeBytes: originalSize,
				newSizeBytes: originalSize,
				status: "skipped",
				reason: "format-not-compressible-without-conversion"
			)
		}

		// Update aggregates on successful reduction
                let saved = max(0, result.originalSizeBytes - result.newSizeBytes)
                if isSuccessful(result) {
                        StatsStore.shared.addProcessed(count: 1)
                        if saved > 0 {
                                StatsStore.shared.addSavedBytes(saved)
                        }
                }
                return result
        }

        private func isSuccessful(_ result: ProcessResult) -> Bool {
                let status = result.status.lowercased()
                return status == "ok" || status == "success"
        }

	private func qualityFor(_ settings: AppSettings) -> Double {
		switch settings.preset {
		case .custom: return settings.customJpegQuality
		case .quality: return 0.95
		case .balanced: return 0.88
		case .saving: return 0.82
		}
	}

	private func reencodeImageIO(inputURL: URL, outputURL: URL, destUTType: CFString, quality: Double?, tiffLZW: Bool, pngLossless: Bool, preserveMetadata: Bool, convertToSRGB: Bool, maxDimension: Int?) -> ProcessResult {
		let fm = FileManager.default
		let originalSize = (try? fm.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? 0
		let resVals = try? inputURL.resourceValues(forKeys: [.contentTypeKey])
		let sourceType = resVals?.contentType
		let sourceFormat = sourceType?.preferredFilenameExtension ?? inputURL.pathExtension.lowercased()

		guard let src = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "cgimage-source-failed")
		}
		guard let baseImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "cgimage-create-failed")
		}
		let srcWidth = baseImage.width
		let srcHeight = baseImage.height
		let useSRGB = convertToSRGB
		let colorSpace: CGColorSpace = useSRGB ? (CGColorSpace(name: CGColorSpace.sRGB) ?? (baseImage.colorSpace ?? CGColorSpaceCreateDeviceRGB())) : (baseImage.colorSpace ?? CGColorSpaceCreateDeviceRGB())
		let (dstW, dstH) = scaledSize(width: srcWidth, height: srcHeight, maxDimension: maxDimension)
		let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
		let image: CGImage
		if let ctx = CGContext(data: nil, width: dstW, height: dstH, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) {
			ctx.interpolationQuality = .high
			ctx.draw(baseImage, in: CGRect(x: 0, y: 0, width: CGFloat(dstW), height: CGFloat(dstH)))
			image = ctx.makeImage() ?? baseImage
		} else {
			image = baseImage
		}
                let overwritingSource = inputURL.path == outputURL.path
                let destinationURL: URL
                if overwritingSource {
                        let tempExtension = outputURL.pathExtension.isEmpty ? sourceFormat : outputURL.pathExtension
                        let tempName = SecurityUtils.createSecureTempFileName(extension: tempExtension)
                        destinationURL = fm.temporaryDirectory.appendingPathComponent(tempName)
                } else {
                        destinationURL = outputURL
                }

                let parentDir = destinationURL.deletingLastPathComponent()
                try? fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
                guard let dest = CGImageDestinationCreateWithURL(destinationURL as CFURL, destUTType, 1, nil) else {
                        return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "cgimage-dest-create-failed")
                }
		var props: [CFString: Any] = [:]
		if let q = quality { props[kCGImageDestinationLossyCompressionQuality] = q }
		if tiffLZW {
			props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFCompression: 5]
		}
		if pngLossless {
			props[kCGImagePropertyPNGDictionary] = [:] // zlib level not publicly available
		}
		// Save metadata (EXIF, IPTC, GPS, TIFF, PNG)
		if preserveMetadata, let allProps = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] {
			var meta = allProps
			// Remove potentially conflicting quality/compression keys
			meta.removeValue(forKey: kCGImageDestinationLossyCompressionQuality)
			// Apply sRGB meta when converting color
			if convertToSRGB {
				meta[kCGImagePropertyColorModel] = kCGImagePropertyColorModelRGB
				meta[kCGImagePropertyProfileName] = "sRGB IEC61966-2.1"
			}
			// Merge original metadata into props
			for (k, v) in meta { props[k] = v }
			// Reset our parameters after merge
			if let q = quality { props[kCGImageDestinationLossyCompressionQuality] = q }
			if tiffLZW { props[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFCompression: 5] }
			if pngLossless { props[kCGImagePropertyPNGDictionary] = [:] }
		}
		// If converting to sRGB but metadata is not preserved - still specify the profile
		if !preserveMetadata && convertToSRGB {
			props[kCGImagePropertyColorModel] = kCGImagePropertyColorModelRGB
			props[kCGImagePropertyProfileName] = "sRGB IEC61966-2.1"
		}
                CGImageDestinationAddImage(dest, image, props as CFDictionary)
                guard CGImageDestinationFinalize(dest) else {
                        return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "cgimage-finalize-failed")
                }
                let newSize = (try? fm.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize

                if newSize >= originalSize {
                        if destinationURL != inputURL {
                                do {
                                        if fm.fileExists(atPath: destinationURL.path) {
                                                try fm.removeItem(at: destinationURL)
                                        }
                                        try fm.copyItem(at: inputURL, to: destinationURL)
                                } catch {
                                        return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: outputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "error", reason: "copy-original-failed")
                                }
                        }

                        let finalOutputURL = overwritingSource ? inputURL : destinationURL
                        return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: finalOutputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "success", reason: "no-gain")
                }

                if overwritingSource {
                        do {
                                if fm.fileExists(atPath: inputURL.path) {
                                        try fm.removeItem(at: inputURL)
                                }
                                try fm.moveItem(at: destinationURL, to: inputURL)
                        } catch {
                                try? fm.removeItem(at: destinationURL)
                                return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "error", reason: "move-failed")
                        }
                }

                let finalOutputURL = overwritingSource ? inputURL : destinationURL
                let saved = originalSize - newSize
                return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: finalOutputURL.path, originalSizeBytes: originalSize, newSizeBytes: newSize, status: "success", reason: saved > 0 ? "imageio-compression" : "no-gain")
        }

	private func reencodeWebPWithEmbedded(inputURL: URL, outputURL: URL, settings: AppSettings, convertToSRGB: Bool, maxDimension: Int?) -> ProcessResult {
		let fm = FileManager.default
		let originalSize = (try? fm.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? 0
		let resVals = try? inputURL.resourceValues(forKeys: [.contentTypeKey])
		let sourceType = resVals?.contentType
		let sourceFormat = sourceType?.preferredFilenameExtension ?? inputURL.pathExtension.lowercased()

		guard let src = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "cgimage-source-failed")
		}
		guard let baseImage = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "cgimage-create-failed")
		}
		let srcW = baseImage.width
		let srcH = baseImage.height
		let (dstW, dstH) = scaledSize(width: srcW, height: srcH, maxDimension: maxDimension)
		let colorSpace: CGColorSpace = convertToSRGB ? (CGColorSpace(name: CGColorSpace.sRGB) ?? (baseImage.colorSpace ?? CGColorSpaceCreateDeviceRGB())) : (baseImage.colorSpace ?? CGColorSpaceCreateDeviceRGB())
		let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
		guard let ctx = CGContext(data: nil, width: dstW, height: dstH, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "bitmap-context-failed")
		}
		ctx.interpolationQuality = .high
		ctx.draw(baseImage, in: CGRect(x: 0, y: 0, width: CGFloat(dstW), height: CGFloat(dstH)))
		guard let dataPtr = ctx.data else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "bitmap-data-missing")
		}
		let bytesPerRow = ctx.bytesPerRow
		let byteCount = bytesPerRow * dstH

		// Immediately copy data to prevent pointer invalidation
		let rgbaData: Data
		do {
			rgbaData = Data(bytes: dataPtr, count: byteCount)
			// Explicitly invalidate context data to prevent dangling pointer usage
			ctx.clear(CGRect(x: 0, y: 0, width: CGFloat(dstW), height: CGFloat(dstH)))
		}
		let encoder = WebPEncoder()
		let q = webPQuality(for: settings)
		guard let webpData = encoder.encodeRGBA(rgbaData, width: dstW, height: dstH, quality: q) else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "embedded-webp-encode-failed")
		}
                let overwritingSource = inputURL.path == outputURL.path
                let destinationURL: URL
                if overwritingSource {
                        let tempName = SecurityUtils.createSecureTempFileName(extension: outputURL.pathExtension.isEmpty ? sourceFormat : outputURL.pathExtension)
                        destinationURL = fm.temporaryDirectory.appendingPathComponent(tempName)
                } else {
                        destinationURL = outputURL
                }

                try? fm.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                do {
                        try webpData.write(to: destinationURL, options: [.atomic])
                } catch {
                        return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "write-failed")
                }
                let newSize = (try? fm.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? originalSize

                if newSize >= originalSize {
                        if destinationURL != inputURL {
                                do {
                                        if fm.fileExists(atPath: destinationURL.path) {
                                                try fm.removeItem(at: destinationURL)
                                        }
                                        try fm.copyItem(at: inputURL, to: destinationURL)
                                } catch {
                                        return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: outputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "error", reason: "copy-original-failed")
                                }
                        }

                        let finalOutputURL = overwritingSource ? inputURL : destinationURL
                        return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: finalOutputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "success", reason: "no-gain")
                }

                if overwritingSource {
                        do {
                                if fm.fileExists(atPath: inputURL.path) {
                                        try fm.removeItem(at: inputURL)
                                }
                                try fm.moveItem(at: destinationURL, to: inputURL)
                        } catch {
                                try? fm.removeItem(at: destinationURL)
                                return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "error", reason: "move-failed")
                        }
                }

                let finalOutputURL = overwritingSource ? inputURL : destinationURL
                return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: finalOutputURL.path, originalSizeBytes: originalSize, newSizeBytes: newSize, status: "success", reason: "webp-compression")
        }

	private func webPQuality(for settings: AppSettings) -> Int {
		switch settings.preset {
		case .custom: return settings.customWebPQuality
		case .quality: return 95
		case .balanced: return 88
		case .saving: return 82
		}
	}

	private func scaledSize(width: Int, height: Int, maxDimension: Int?) -> (Int, Int) {
		guard let maxDim = maxDimension, maxDim > 0 else { return (width, height) }
		let w = CGFloat(width)
		let h = CGFloat(height)
		let maxD = CGFloat(maxDim)
		let scale = min(1.0, maxD / max(w, h))
		let newW = Int((w * scale).rounded(.toNearestOrAwayFromZero))
		let newH = Int((h * scale).rounded(.toNearestOrAwayFromZero))
		return (max(newW, 1), max(newH, 1))
	}

        private static func computeOutputURL(for inputURL: URL, mode: SaveMode) -> URL {
                switch mode {
                case .suffix:
                        let ext = inputURL.pathExtension
                        let base = inputURL.deletingPathExtension().lastPathComponent
                        let dir = inputURL.deletingLastPathComponent()
                        let sanitizedBase = SecurityUtils.sanitizeFilename(base)
                        let sanitizedExt = SecurityUtils.sanitizeFilename(ext)
                        let filename = sanitizedExt.isEmpty ? "\(sanitizedBase)_compressed" : "\(sanitizedBase)_compressed.\(sanitizedExt)"
                        return dir.appendingPathComponent(filename)
		case .separateFolder:
			let dir = inputURL.deletingLastPathComponent()
			let outDir = dir.appendingPathComponent("Compressor")
			let ext = inputURL.pathExtension
			let base = inputURL.deletingPathExtension().lastPathComponent
			return outDir.appendingPathComponent("\(base)").appendingPathExtension(ext)
		case .overwrite:
                        return inputURL
                }
        }
}
#else

public final class CompressionService {
        public init() {}

        public func compressFile(at inputURL: URL, settings: AppSettings) -> ProcessResult {
                let format = inputURL.pathExtension.lowercased()
                let originalSize = (try? FileManager.default.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? 0
                return ProcessResult(
                        sourceFormat: format,
                        targetFormat: format,
                        originalPath: inputURL.path,
                        outputPath: inputURL.path,
                        originalSizeBytes: originalSize,
                        newSizeBytes: originalSize,
                        status: "skipped",
                        reason: "compression-unavailable"
                )
        }
}
#endif
