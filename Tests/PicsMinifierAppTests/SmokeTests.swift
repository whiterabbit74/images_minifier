import XCTest
@testable import PicsMinifierCore

final class SmokeTests: XCTestCase {
	func testEnumerateEmptyDirectoryReturnsEmpty() throws {
		let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
		let walker = FileWalker()
		let files = walker.enumerateSupportedFiles(at: temp)
		XCTAssertTrue(files.isEmpty)
	}
}


