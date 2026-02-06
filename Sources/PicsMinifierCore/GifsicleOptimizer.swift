import Foundation

#if canImport(Darwin)
import Darwin

public final class GifsicleOptimizer {
	public init() {}

	public func optimize(inputURL: URL, outputURL: URL, lossy: Bool = false) -> ProcessResult {
		let fm = FileManager.default
		let originalSize = (try? fm.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? 0
		let sourceFormat = inputURL.pathExtension.lowercased()

		guard let tool = locateGifsicle() else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "gifsicle-not-found")
		}
		try? fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
		let process = Process()
		process.executableURL = tool
		var args = ["--optimize=3"]
        if lossy {
            args.append("--lossy=80")
        }
		// Если перезаписываем тот же файл — пишем во временный, затем заменяем
		let overwriteSamePath = (inputURL.path == outputURL.path)
		let finalOutputURL: URL
		if overwriteSamePath {
			finalOutputURL = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".gif")
		} else {
			finalOutputURL = outputURL
		}
		args += ["--output", finalOutputURL.path, inputURL.path]
		process.arguments = args
		let errorPipe = Pipe()
		let outputPipe = Pipe()
		process.standardError = errorPipe
		process.standardOutput = outputPipe

		// Ensure pipes are properly closed
		defer {
			try? errorPipe.fileHandleForReading.close()
			try? outputPipe.fileHandleForReading.close()
			try? errorPipe.fileHandleForWriting.close()
			try? outputPipe.fileHandleForWriting.close()
		}

		do {
			try process.run()
			process.waitUntilExit()
		} catch {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "gifsicle-launch-failed")
		}
		guard process.terminationStatus == 0 else {
			return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "gifsicle-nonzero-exit")
		}
		if overwriteSamePath {
			// Заменим оригинал результатом
			try? fm.removeItem(at: inputURL)
			try? fm.moveItem(at: finalOutputURL, to: inputURL)
		}
		let attrsPath = overwriteSamePath ? inputURL.path : outputURL.path
		let newSize = (try? fm.attributesOfItem(atPath: attrsPath)[.size] as? NSNumber)?.int64Value ?? originalSize
		let outPath = overwriteSamePath ? inputURL.path : outputURL.path
		return ProcessResult(sourceFormat: sourceFormat, targetFormat: sourceFormat, originalPath: inputURL.path, outputPath: outPath, originalSizeBytes: originalSize, newSizeBytes: newSize, status: "ok", reason: newSize <= originalSize ? nil : "no-gain")
	}

	private func locateGifsicle() -> URL? {
		let fm = FileManager.default
		var candidates: [URL] = []
		// PICS_GIFSICLE_PATH (override): если задан и невалиден — НЕ продолжаем поиск
		if let overridePath = ProcessInfo.processInfo.environment["PICS_GIFSICLE_PATH"], !overridePath.isEmpty {
			let url = URL(fileURLWithPath: overridePath)
			if fm.isExecutableFile(atPath: url.path) { return url }
			return nil
		}
		// App bundle
		if let bundleURL = Bundle.main.url(forResource: "gifsicle", withExtension: nil) {
			candidates.append(bundleURL)
		} else if let resDir = Bundle.main.resourceURL?.appendingPathComponent("gifsicle") {
			candidates.append(resDir)
		}
		// Dev paths
		candidates.append(contentsOf: [
			URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("gifsicle"),
			URL(fileURLWithPath: "/opt/homebrew/bin/gifsicle"),
			URL(fileURLWithPath: "/usr/local/bin/gifsicle")
		])
		for url in candidates {
			if fm.fileExists(atPath: url.path) {
				if !fm.isExecutableFile(atPath: url.path) {
					url.withUnsafeFileSystemRepresentation { cstr in
						if let cstr = cstr { chmod(cstr, 0o755) }
					}
				}
				if fm.isExecutableFile(atPath: url.path) { return url }
			}
		}
		return nil
	}
}

#else

public final class GifsicleOptimizer {
        public init() {}

        public func optimize(inputURL: URL, outputURL: URL) -> ProcessResult {
                let originalSize = (try? FileManager.default.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? 0
                let format = inputURL.pathExtension.lowercased()
                return ProcessResult(sourceFormat: format, targetFormat: format, originalPath: inputURL.path, outputPath: inputURL.path, originalSizeBytes: originalSize, newSizeBytes: originalSize, status: "skipped", reason: "gifsicle-unavailable")
        }
}

#endif


