import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import PicsMinifierCore

final class WebPIntegrationTests: XCTestCase {
    func testWebPReducedSizeWithLowerQuality() throws {
        let encoder = WebPEncoder()
        let availability = encoder.availability()
        guard availability == .embedded || availability == .systemCodec else {
            throw XCTSkip("No WebP encoder available (system or embedded)")
        }

        // Generate a deterministic RGBA gradient image
        let width = 256
        let height = 256
        let bitsPerComponent = 8
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))

        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue) else {
            XCTFail("Failed to create CGContext")
            return
        }
        // Fill with gradient by drawing small rects
        for y in 0..<height {
            for x in 0..<width {
                let r = CGFloat(x) / CGFloat(width - 1)
                let g = CGFloat(y) / CGFloat(height - 1)
                let b = CGFloat((x + y) % width) / CGFloat(width - 1)
                ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
                ctx.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
        guard let cgImage = ctx.makeImage() else {
            XCTFail("Failed to make CGImage")
            return
        }

        // Prepare temp file
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let inputURL = tmpDir.appendingPathComponent("input.webp")

        // Create initial WebP with higher quality
        if availability == .systemCodec {
            let webpUT = UTType(importedAs: "org.webmproject.webp").identifier as CFString
            guard let dest = CGImageDestinationCreateWithURL(inputURL as CFURL, webpUT, 1, nil) else {
                XCTFail("Failed to create WebP destination")
                return
            }
            let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.95]
            CGImageDestinationAddImage(dest, cgImage, props as CFDictionary)
            XCTAssertTrue(CGImageDestinationFinalize(dest))
        } else {
            // embedded
            // Extract RGBA data from CGImage
            let outCtx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)!
            outCtx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
            let stride = outCtx.bytesPerRow
            let count = stride * height
            let rgba = Data(bytes: outCtx.data!, count: count)
            let webpHigh = encoder.encodeRGBA(rgba, width: width, height: height, quality: 90)
            XCTAssertNotNil(webpHigh)
            try webpHigh!.write(to: inputURL)
        }

        // Run CompressionService with lower quality preset
        var settings = AppSettings()
        settings.preserveMetadata = true
        settings.convertToSRGB = true
        settings.saveMode = .suffix
        let res = CompressionService().compressFile(at: inputURL, settings: settings)
        XCTAssertEqual(res.status, "ok")

        let origSize = (try FileManager.default.attributesOfItem(atPath: inputURL.path)[.size] as? NSNumber)?.int64Value ?? -1
        XCTAssertGreaterThan(origSize, 0)
        XCTAssertLessThanOrEqual(res.newSizeBytes, origSize)
    }
}


