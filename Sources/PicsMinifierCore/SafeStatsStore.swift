import Foundation

/// Thread-safe statistics store with overflow protection
public final class SafeStatsStore {
    public static let shared = SafeStatsStore()

    private let userDefaults: UserDefaults
    private let queue = DispatchQueue(label: "com.picsminifier.stats", qos: .utility)
    private let maxValue: Int64 = Int64.max / 2 // Prevent overflow

    private init() {
        // Use app-specific suite to avoid conflicts
        userDefaults = UserDefaults(suiteName: "com.picsminifier.stats") ?? .standard
    }

    // MARK: - Thread-Safe Operations

    public func processedCount() -> Int {
        return queue.sync {
            return userDefaults.integer(forKey: "processedCount")
        }
    }

    public func totalSavedBytes() -> Int64 {
        return queue.sync {
            return userDefaults.object(forKey: "totalSavedBytes") as? Int64 ?? 0
        }
    }

    public func addProcessedFile() {
        queue.async {
            let current = self.userDefaults.integer(forKey: "processedCount")
            // Prevent integer overflow
            let newValue = current < Int.max - 1 ? current + 1 : current
            self.userDefaults.set(newValue, forKey: "processedCount")
        }
    }

    public func addSavedBytes(_ bytes: Int64) {
        guard bytes > 0 && bytes < maxValue else { return }

        queue.async {
            let current = self.userDefaults.object(forKey: "totalSavedBytes") as? Int64 ?? 0
            // Prevent overflow
            let newValue = current < self.maxValue - bytes ? current + bytes : self.maxValue
            self.userDefaults.set(newValue, forKey: "totalSavedBytes")
        }
    }

    public func reset() {
        queue.async {
            self.userDefaults.removeObject(forKey: "processedCount")
            self.userDefaults.removeObject(forKey: "totalSavedBytes")
            self.userDefaults.synchronize()
        }
    }

    // MARK: - Atomic Updates

    public func updateStats(processedFiles: Int, savedBytes: Int64) {
        guard processedFiles >= 0 && savedBytes >= 0 && savedBytes < maxValue else { return }

        queue.async {
            let currentCount = self.userDefaults.integer(forKey: "processedCount")
            let currentBytes = self.userDefaults.object(forKey: "totalSavedBytes") as? Int64 ?? 0

            // Safe arithmetic with overflow protection
            let newCount = currentCount < Int.max - processedFiles ? currentCount + processedFiles : Int.max
            let newBytes = currentBytes < self.maxValue - savedBytes ? currentBytes + savedBytes : self.maxValue

            self.userDefaults.set(newCount, forKey: "processedCount")
            self.userDefaults.set(newBytes, forKey: "totalSavedBytes")
            self.userDefaults.synchronize()
        }
    }

    // MARK: - Safe Export

    public func exportStats() -> (processedCount: Int, totalSavedBytes: Int64) {
        return queue.sync {
            let count = self.userDefaults.integer(forKey: "processedCount")
            let bytes = self.userDefaults.object(forKey: "totalSavedBytes") as? Int64 ?? 0
            return (count, bytes)
        }
    }
}