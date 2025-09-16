import Foundation

#if canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import ImageIO
import UniformTypeIdentifiers
import WebPShims

public enum WebPAvailability {
        case systemCodec
        case embedded
        case unavailable
}

public final class WebPEncoder {
        public init() {}

        public func availability() -> WebPAvailability {
                let webp = UTType(importedAs: "org.webmproject.webp").identifier as CFString
                if let types = CGImageDestinationCopyTypeIdentifiers() as? [CFString], types.contains(webp) {
                        return .systemCodec
                }
                return webp_embedded_available() != 0 ? .embedded : .unavailable
        }

        public func encodeRGBA(_ rgba: Data, width: Int, height: Int, quality: Int) -> Data? {
                var outputPtr: UnsafeMutablePointer<UInt8>? = nil
                var outputSize: Int = 0
                let stride = width * 4
                let q: Float = Float(quality)

                defer {
                        if let ptr = outputPtr {
                                webp_free_buffer(ptr)
                        }
                }

                let success: Int = rgba.withUnsafeBytes { rawBuf in
                        guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                        var sizeT: size_t = 0
                        let res = webp_encode_rgba(base, Int32(width), Int32(height), Int32(stride), q, &outputPtr, &sizeT)
                        outputSize = Int(sizeT)
                        return Int(res)
                }

                guard success != 0, let outNonNil = outputPtr, outputSize > 0 else {
                        return nil
                }

                return Data(bytes: outNonNil, count: outputSize)
        }

        public func decodeRGBA(_ webpData: Data) -> (rgba: Data, width: Int, height: Int, stride: Int)? {
                var outPtr: UnsafeMutablePointer<UInt8>? = nil
                var w: Int32 = 0
                var h: Int32 = 0
                var stride: Int32 = 0

                defer {
                        if let ptr = outPtr {
                                webp_free_buffer(ptr)
                        }
                }

                let ok: Int = webpData.withUnsafeBytes { rawBuf in
                        guard let base = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return 0 }
                        return Int(webp_decode_rgba(base, webpData.count, &outPtr, &w, &h, &stride))
                }

                guard ok != 0, let out = outPtr, w > 0, h > 0, stride > 0 else {
                        return nil
                }

                let byteCount = Int(stride) * Int(h)
                let data = Data(bytes: out, count: byteCount)
                return (data, Int(w), Int(h), Int(stride))
        }
}
#else

public enum WebPAvailability {
        case unavailable
}

public final class WebPEncoder {
        public init() {}

        public func availability() -> WebPAvailability { .unavailable }

        public func encodeRGBA(_ data: Data, width: Int, height: Int, quality: Int) -> Data? { nil }

        public func decodeRGBA(_ webpData: Data) -> (rgba: Data, width: Int, height: Int, stride: Int)? { nil }
}

#endif
