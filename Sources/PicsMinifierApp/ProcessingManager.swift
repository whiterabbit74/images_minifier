import Foundation
import PicsMinifierCore
import AppKit

final class ProcessingManager {
	static let shared = ProcessingManager()
	private let smartCompressor = SmartCompressor() // Modern compression engine
	private let legacyService = CompressionService() // Fallback
	private let logger = CSVLogger(logURL: AppPaths.logCSVURL())
    private var isCancelled: Bool = false
    private var useModernCompressors: Bool = true

	private init() {}

	func process(urls: [URL], settings: AppSettings) async {
        isCancelled = false
		let maxConcurrent = max(2, ProcessInfo.processInfo.processorCount - 1)
		await withTaskGroup(of: Void.self) { group in
			var it = urls.makeIterator()
			// Первичное окно
			for _ in 0..<maxConcurrent {
				guard let url = it.next() else { break }
				group.addTask { [weak self] in
					guard let self = self else { return }

					// Check for cancellation before starting work
					guard !Task.isCancelled else { return }

					let result = self.compressFile(at: url, settings: settings)

					// Check for cancellation after potentially long operation
					guard !Task.isCancelled else { return }

					self.logger?.append(result)
					NotificationCenter.default.post(name: .processingResult, object: result)

					if result.status == "ok" && result.originalSizeBytes > result.newSizeBytes {
						DispatchQueue.main.async {
							guard !Task.isCancelled else { return }
							NSApp.dockTile.badgeLabel = "✓"
							AppUIManager.shared.showDockBounce()
						}
					}
				}
			}
			// Подкладываем оставшиеся задачи, дожидаясь завершения по одной
			while let url = it.next() {
				if isCancelled { break }
				_ = await group.next()
				group.addTask { [weak self] in
					guard let self = self else { return }
					if Task.isCancelled { return }
					let result = self.compressFile(at: url, settings: settings)
					self.logger?.append(result)
					NotificationCenter.default.post(name: .processingResult, object: result)
					if result.status == "ok" && result.originalSizeBytes > result.newSizeBytes {
						DispatchQueue.main.async {
							NSApp.dockTile.badgeLabel = "✓"
							AppUIManager.shared.showDockBounce()
						}
					}
				}
			}
			await group.waitForAll()
		}

		// Очистим бейдж и уведомим об окончании партии
		DispatchQueue.main.async {
			NSApp.dockTile.badgeLabel = ""
		}
		NotificationCenter.default.post(name: .processingFinished, object: urls.count)
	}

    func cancel() {
        isCancelled = true
    }

    // MARK: - Private Methods

    private func compressFile(at url: URL, settings: AppSettings) -> ProcessResult {
        // Use modern SmartCompressor when enabled, fall back to legacy service
        if useModernCompressors {
            return smartCompressor.compressFile(at: url, settings: settings)
        } else {
            return legacyService.compressFile(at: url, settings: settings)
        }
    }

    // MARK: - Public Configuration

    func setUseModernCompressors(_ enabled: Bool) {
        useModernCompressors = enabled
        print("🔧 Modern compressors: \(enabled ? "enabled" : "disabled")")
    }

    // Get available modern compression tools
    func getAvailableTools() -> [String: Bool] {
        let fm = FileManager.default
        return [
            "MozJPEG": fm.isExecutableFile(atPath: "/opt/homebrew/bin/cjpeg") || fm.isExecutableFile(atPath: "/usr/local/bin/cjpeg"),
            "Oxipng": fm.isExecutableFile(atPath: "/opt/homebrew/bin/oxipng") || fm.isExecutableFile(atPath: "/usr/local/bin/oxipng"),
            "Gifsicle": fm.isExecutableFile(atPath: "/opt/homebrew/bin/gifsicle") || fm.isExecutableFile(atPath: "/usr/local/bin/gifsicle"),
            "AVIF": fm.isExecutableFile(atPath: "/opt/homebrew/bin/avifenc") || fm.isExecutableFile(atPath: "/usr/local/bin/avifenc")
        ]
    }
}


