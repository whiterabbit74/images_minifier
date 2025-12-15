import Foundation

public enum CompressionPreset: String, CaseIterable, Codable {
	case quality
	case balanced
	case saving
	case auto
	case custom
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

    // Advanced Custom Settings
    public var customJpegQuality: Double = 0.82
    public var customPngLevel: Int = 3
    public var customAvifQuality: Int = 28
    public var customAvifSpeed: Int = 4

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

public struct SessionStats: Codable, Equatable {
	public var totalFiles: Int = 0
	public var processedFiles: Int = 0
	public var totalOriginalSize: Int64 = 0
	public var totalCompressedSize: Int64 = 0
	public var errorCount: Int = 0
	public var totalInBatch: Int = 0
	public var successfulFiles: Int = 0
	public var failedFiles: Int = 0
	public var skippedFiles: Int = 0

	public init() {}

	public var processedCount: Int {
		return processedFiles
	}

	public var compressionRatio: Double {
		guard totalOriginalSize > 0 else { return 0.0 }
		return Double(totalCompressedSize) / Double(totalOriginalSize)
	}

	public var savedBytes: Int64 {
		return totalOriginalSize - totalCompressedSize
	}
}
