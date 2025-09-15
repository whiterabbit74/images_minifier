import XCTest
import Foundation
@testable import PicsMinifierCore

final class GifsicleTests: XCTestCase {
    private func writeTinyGIF(to url: URL) throws {
        // 1x1 px GIF89a
        let base64 = "R0lGODdhAQABAPAAAP///wAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw=="
        let data = Data(base64Encoded: base64)!
        try data.write(to: url)
    }

    func testGifSkippedWhenGifsicleDisabled() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let gifURL = tmp.appendingPathComponent("a.gif")
        try writeTinyGIF(to: gifURL)

        var settings = AppSettings()
        settings.enableGifsicle = false
        settings.saveMode = .suffix

        let result = CompressionService().compressFile(at: gifURL, settings: settings)
        XCTAssertEqual(result.status, "skipped")
        XCTAssertEqual(result.reason, "gifsicle-disabled")
    }

    func testGifSkippedWhenGifsicleNotFound() throws {
        // Зададим путь override на несуществующий бинарь
        setenv("PICS_GIFSICLE_PATH", "/nonexistent/path/gifsicle", 1)

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let gifURL = tmp.appendingPathComponent("b.gif")
        try writeTinyGIF(to: gifURL)

        var settings = AppSettings()
        settings.enableGifsicle = true
        settings.saveMode = .suffix

        let result = CompressionService().compressFile(at: gifURL, settings: settings)
        XCTAssertEqual(result.status, "skipped")
        XCTAssertEqual(result.reason, "gifsicle-not-found")
    }
}


