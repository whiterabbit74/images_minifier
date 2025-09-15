import XCTest
@testable import PicsMinifierCore

final class CSVLoggerTests: XCTestCase {
    func testHeaderAndAppend() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logURL = tempDir.appendingPathComponent("csvlogger_\(UUID().uuidString).csv")
        guard let logger = CSVLogger(logURL: logURL) else { XCTFail("logger nil"); return }
        // Header should be created
        let header = try String(contentsOf: logURL, encoding: .utf8).split(separator: "\n").first!
        XCTAssertEqual(String(header), "timestamp,sourceFormat,targetFormat,originalPath,outputPath,originalSizeBytes,newSizeBytes,bytesSaved,savedRatio,status,reason")

        // Append one record
        let record = ProcessResult(
            sourceFormat: "jpeg",
            targetFormat: "jpeg",
            originalPath: "/tmp/a.jpg",
            outputPath: "/tmp/a_compressed.jpg",
            originalSizeBytes: 1000,
            newSizeBytes: 800,
            status: "ok",
            reason: nil
        )
        logger.append(record)
        // Wait until async write completes (up to ~1s)
        var linesCount = 0
        for _ in 0..<50 {
            let content = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
            linesCount = content.split(separator: "\n").count
            if linesCount >= 2 { break }
            usleep(20_000)
        }
        XCTAssertEqual(linesCount, 2)
    }
}


