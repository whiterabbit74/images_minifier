import XCTest
import Foundation
@testable import PicsMinifierCore

final class WebPTests: XCTestCase {
    func testWebPInputHandledByEitherSystemOrEmbedded() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let webpURL = tmp.appendingPathComponent("a.webp")
        // Минимальный контент (может быть невалидным — тест должен быть устойчивым)
        try Data([0x52, 0x49, 0x46, 0x46]).write(to: webpURL)

        let settings = AppSettings()
        let result = CompressionService().compressFile(at: webpURL, settings: settings)
        XCTAssertEqual(result.targetFormat, "webp")
        XCTAssertEqual(result.sourceFormat, "webp")
        // Допускаем три исхода: системный кодек, embedded успешно, либо корректный skip
        XCTAssertTrue([
            "ok",
            "skipped"
        ].contains(result.status))
    }
}


