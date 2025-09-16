import Foundation

public final class StatsStore {
	public static let shared = StatsStore()

	private let defaults: UserDefaults
	private let processedKey = "stats.allTimeProcessedCount"
	private let savedBytesKey = "stats.allTimeSavedBytes"

	// Thread safety: Use serial queue for atomic operations
	private let queue = DispatchQueue(label: "com.picsminifier.stats", qos: .utility)

	public init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	public var allTimeProcessedCount: Int {
		queue.sync {
			defaults.integer(forKey: processedKey)
		}
	}

	public var allTimeSavedBytes: Int64 {
		queue.sync {
			Int64(defaults.integer(forKey: savedBytesKey))
		}
	}

	public func addProcessed(count: Int) {
		guard count > 0 else { return }
		queue.sync {
			let current = defaults.integer(forKey: processedKey)
			let newValue = max(0, current + count)
			defaults.set(newValue, forKey: processedKey)
		}
	}

	public func addSavedBytes(_ bytes: Int64) {
		guard bytes > 0 else { return }
		queue.sync {
			let current = Int64(defaults.integer(forKey: savedBytesKey))
			let overflowSafe = current > (Int64.max - bytes) ? Int64.max : current + bytes

			// Additional overflow protection for Int() cast
			let finalValue: Int
			if overflowSafe > Int64(Int.max) {
				finalValue = Int.max
			} else if overflowSafe < Int64(Int.min) {
				finalValue = Int.min
			} else {
				finalValue = Int(overflowSafe)
			}

			defaults.set(finalValue, forKey: savedBytesKey)
		}
	}

	public func resetAll() {
		queue.sync {
			defaults.set(0, forKey: processedKey)
			defaults.set(0, forKey: savedBytesKey)
		}
	}
}


