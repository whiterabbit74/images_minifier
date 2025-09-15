import XCTest
@testable import PicsMinifierCore

final class WebPEncoderAvailabilityTests: XCTestCase {
    func testEmbeddedEncoderEncodesRGBAWhenAvailable() throws {
        let encoder = WebPEncoder()
        guard encoder.availability() == .embedded else {
            throw XCTSkip("embedded libwebp unavailable; skipping encode test")
        }

        let width = 8
        let height = 8
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                rgba[i + 0] = 255 // R
                rgba[i + 1] = UInt8((x * 255) / max(1, width - 1)) // G gradient
                rgba[i + 2] = UInt8((y * 255) / max(1, height - 1)) // B gradient
                rgba[i + 3] = 255 // A
            }
        }
        let data = Data(rgba)
        let q = 80
        let webp = encoder.encodeRGBA(data, width: width, height: height, quality: q)
        XCTAssertNotNil(webp)
        XCTAssertGreaterThan(webp!.count, 0)
    }
}


