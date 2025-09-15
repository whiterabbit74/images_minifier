import Foundation

public final class StatsStore {
	public static let shared = StatsStore()

	private let defaults: UserDefaults
	private let processedKey = "stats.allTimeProcessedCount"
	private let savedBytesKey = "stats.allTimeSavedBytes"

	public init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	public var allTimeProcessedCount: Int {
		defaults.integer(forKey: processedKey)
	}

	public var allTimeSavedBytes: Int64 {
		Int64(defaults.integer(forKey: savedBytesKey))
	}

	public func addProcessed(count: Int) {
		guard count > 0 else { return }
		let newValue = max(0, allTimeProcessedCount + count)
		defaults.set(newValue, forKey: processedKey)
	}

	public func addSavedBytes(_ bytes: Int64) {
		guard bytes > 0 else { return }
		let current = allTimeSavedBytes
		let overflowSafe = current > (Int64.max - bytes) ? Int64.max : current + bytes
		defaults.set(Int(overflowSafe), forKey: savedBytesKey)
	}

	public func resetAll() {
		defaults.set(0, forKey: processedKey)
		defaults.set(0, forKey: savedBytesKey)
	}
}


