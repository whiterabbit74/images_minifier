import XCTest
@testable import PicsMinifierCore

final class StatsStoreTests: XCTestCase {
    func testAddProcessedAndSavedBytes() throws {
        let suiteName = "test.stats.\(UUID().uuidString)"
        guard let ud = UserDefaults(suiteName: suiteName) else { XCTFail("ud"); return }
        let store = StatsStore(defaults: ud)
        XCTAssertEqual(store.allTimeProcessedCount, 0)
        XCTAssertEqual(store.allTimeSavedBytes, 0)

        store.addProcessed(count: 3)
        store.addSavedBytes(1024)
        XCTAssertEqual(store.allTimeProcessedCount, 3)
        XCTAssertEqual(store.allTimeSavedBytes, 1024)

        // Negative/zero should not change
        store.addProcessed(count: 0)
        store.addSavedBytes(0)
        XCTAssertEqual(store.allTimeProcessedCount, 3)
        XCTAssertEqual(store.allTimeSavedBytes, 1024)
    }
}


