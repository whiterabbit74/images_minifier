import Foundation

public final class CSVLogger {
	private let logURL: URL
	private let queue = DispatchQueue(label: "csv.logger.queue", qos: .utility)

	public init?(logURL: URL) {
		self.logURL = logURL
		let fm = FileManager.default
		if !fm.fileExists(atPath: logURL.path) {
			let initial = Self.composeCSV(processed: StatsStore.shared.allTimeProcessedCount,
											  saved: StatsStore.shared.allTimeSavedBytes)
			try? initial.write(to: logURL, options: [.atomic])
		} else {
			// Приводим к новому формату при инициализации
			let initial = Self.composeCSV(processed: StatsStore.shared.allTimeProcessedCount,
											  saved: StatsStore.shared.allTimeSavedBytes)
			try? initial.write(to: logURL, options: [.atomic])
		}
	}

	public func append(_ record: ProcessResult) {
		queue.async {
			let processed = StatsStore.shared.allTimeProcessedCount
			let saved = StatsStore.shared.allTimeSavedBytes
			let data = Self.composeCSV(processed: processed, saved: saved)
			try? data.write(to: self.logURL, options: [.atomic])
		}
	}

	private static func composeCSV(processed: Int, saved: Int64) -> Data {
		let header = "processedTotal,savedBytesTotal\n"
		let body = "\(processed),\(saved)\n"
		return (header + body).data(using: .utf8) ?? Data()
	}
}


