import Foundation
import PicsMinifierCore
import AppKit

extension Notification.Name {
	static let processingResult = Notification.Name("PicsMinifier.processingResult")
    static let processingFinished = Notification.Name("PicsMinifier.processingFinished")
}

final class ProcessingManager {
	static let shared = ProcessingManager()
	private let service = CompressionService()
	private let logger = CSVLogger(logURL: AppPaths.logCSVURL())
    private var isCancelled: Bool = false

	private init() {}

	func process(urls: [URL], settings: AppSettings) async {
        isCancelled = false
		let maxConcurrent = max(2, ProcessInfo.processInfo.processorCount - 1)
		await withTaskGroup(of: Void.self) { group in
			var it = urls.makeIterator()
			// Первичное окно
			for _ in 0..<maxConcurrent {
				guard let url = it.next() else { break }
				group.addTask { [service, logger] in
					if Task.isCancelled { return }
					let result = service.compressFile(at: url, settings: settings)
					logger?.append(result)
					NotificationCenter.default.post(name: .processingResult, object: result)
					if result.status == "ok" && result.originalSizeBytes > result.newSizeBytes {
						DispatchQueue.main.async {
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
				group.addTask { [service, logger] in
					if Task.isCancelled { return }
					let result = service.compressFile(at: url, settings: settings)
					logger?.append(result)
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
}


