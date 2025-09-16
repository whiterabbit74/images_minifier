import Foundation

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers

public struct FileWalker {
	public init() {}

	public func enumerateSupportedFiles(at url: URL) -> [URL] {
		var results: [URL] = []
		let fm = FileManager.default
		var isDir: ObjCBool = false
		if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
			if isDir.boolValue {
				if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
					for case let fileURL as URL in enumerator {
						if isSupported(fileURL) { results.append(fileURL) }
					}
				}
			} else {
				if isSupported(url) { results.append(url) }
			}
		}
		return results
	}

	private func isSupported(_ url: URL) -> Bool {
		guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
			return false
		}
		return Self.supportedTypes.contains { type.conforms(to: $0) }
	}

	private static let supportedTypes: [UTType] = {
		return [
			UTType.jpeg,
			UTType.png,
			UTType.bmp,
			UTType.gif,
			UTType.heic,
			UTType.heif,
			UTType(importedAs: "org.webmproject.webp")
		]
	}()
}
#else

public struct FileWalker {
        public init() {}

        public func enumerateSupportedFiles(at url: URL) -> [URL] {
                var results: [URL] = []
                let fm = FileManager.default
                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return results }

                if isDir.boolValue {
                        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
                                for case let fileURL as URL in enumerator {
                                        if isSupported(fileURL) { results.append(fileURL) }
                                }
                        }
                } else {
                        if isSupported(url) { results.append(url) }
                }

                return results
        }

        private func isSupported(_ url: URL) -> Bool {
                let supportedExtensions: Set<String> = ["jpg", "jpeg", "png", "bmp", "gif", "heic", "heif", "webp"]
                return supportedExtensions.contains(url.pathExtension.lowercased())
        }
}

#endif


