import Foundation

public enum CompressionPreset: String, CaseIterable, Codable {
	case quality
	case balanced
	case saving
	case auto
}

public enum SaveMode: String, CaseIterable, Codable {
	case suffix
	case separateFolder
	case overwrite
}

public enum AppearanceMode: String, CaseIterable, Codable {
	case light = "light"
	case dark = "dark"
	case auto = "auto"
}

public struct AppSettings: Codable, Equatable {
	public var preset: CompressionPreset = .balanced
	public var saveMode: SaveMode = .suffix
	public var preserveMetadata: Bool = true
	public var convertToSRGB: Bool = false
	public var enableGifsicle: Bool = true
	public var maxDimension: Int? = nil

	public init() {}
}

public struct ProcessResult: Codable, Equatable {
	public var sourceFormat: String
	public var targetFormat: String
	public var originalPath: String
	public var outputPath: String
	public var originalSizeBytes: Int64
	public var newSizeBytes: Int64
	public var status: String
	public var reason: String?

	public init(sourceFormat: String, targetFormat: String, originalPath: String, outputPath: String, originalSizeBytes: Int64, newSizeBytes: Int64, status: String, reason: String? = nil) {
		self.sourceFormat = sourceFormat
		self.targetFormat = targetFormat
		self.originalPath = originalPath
		self.outputPath = outputPath
		self.originalSizeBytes = originalSizeBytes
		self.newSizeBytes = newSizeBytes
		self.status = status
		self.reason = reason
	}
}


