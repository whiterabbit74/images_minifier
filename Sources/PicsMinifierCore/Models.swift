import Foundation

public enum CompressionPreset: String, CaseIterable, Codable {
	case quality
	case balanced
	case saving
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

public enum ResizeCondition: String, CaseIterable, Codable {
    case width
    case height
    case fit // Longest Edge
}

public struct AppSettings: Codable, Equatable {
    public var preset: CompressionPreset = .balanced
    public var saveMode: SaveMode = .suffix
    public var preserveMetadata: Bool = true
    public var convertToSRGB: Bool = false
    public var enableGifsicle: Bool = true
    public var maxDimension: Int? = nil // Legacy, keep for compatibility if needed or replace logic
    public var enableGifLossy: Bool = false
    public var enableSvgcleaner: Bool = true
    public var svgPrecision: Int = 3
    public var svgMultipass: Bool = false

    // Resizing
    public var resizeEnabled: Bool = false
    public var resizeValue: Int = 1920
    public var resizeCondition: ResizeCondition = .fit

    // Advanced Custom Settings
    public var customJpegQuality: Double = 0.84
    public var customPngLevel: Int = 4
    public var customAvifQuality: Int = 28
    public var customAvifSpeed: Int = 3
    public var customWebPQuality: Int = 88
    public var customWebPMethod: Int = 5
    
    // Workflow
    public var compressImmediately: Bool = true // Default to true

    public init() {}
}

public struct UserPreset: Codable, Identifiable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var customJpegQuality: Double
    public var customPngLevel: Int
    public var customAvifQuality: Int
    public var customAvifSpeed: Int
    public var customWebPQuality: Int
    public var customWebPMethod: Int
    public var enableSvgcleaner: Bool
    public var svgPrecision: Int
    public var svgMultipass: Bool
    public var enableGifsicle: Bool
    public var preserveMetadata: Bool
    public var convertToSRGB: Bool
    
    public init(name: String, settings: AppSettings) {
        self.name = name
        self.customJpegQuality = settings.customJpegQuality
        self.customPngLevel = settings.customPngLevel
        self.customAvifQuality = settings.customAvifQuality
        self.customAvifSpeed = settings.customAvifSpeed
        self.customWebPQuality = settings.customWebPQuality
        self.customWebPMethod = settings.customWebPMethod
        self.enableSvgcleaner = settings.enableSvgcleaner
        self.svgPrecision = settings.svgPrecision
        self.svgMultipass = settings.svgMultipass
        self.enableGifsicle = settings.enableGifsicle
        self.preserveMetadata = settings.preserveMetadata
        self.convertToSRGB = settings.convertToSRGB
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.customJpegQuality = try container.decodeIfPresent(Double.self, forKey: .customJpegQuality) ?? 0.82
        self.customPngLevel = try container.decodeIfPresent(Int.self, forKey: .customPngLevel) ?? 3
        self.customAvifQuality = try container.decodeIfPresent(Int.self, forKey: .customAvifQuality) ?? 28
        self.customAvifSpeed = try container.decodeIfPresent(Int.self, forKey: .customAvifSpeed) ?? 4
        self.customWebPQuality = try container.decodeIfPresent(Int.self, forKey: .customWebPQuality) ?? 88
        self.customWebPMethod = try container.decodeIfPresent(Int.self, forKey: .customWebPMethod) ?? 5
        self.enableSvgcleaner = try container.decodeIfPresent(Bool.self, forKey: .enableSvgcleaner) ?? true
        self.svgPrecision = try container.decodeIfPresent(Int.self, forKey: .svgPrecision) ?? 3
        self.svgMultipass = try container.decodeIfPresent(Bool.self, forKey: .svgMultipass) ?? false
        self.enableGifsicle = try container.decodeIfPresent(Bool.self, forKey: .enableGifsicle) ?? true
        self.preserveMetadata = try container.decodeIfPresent(Bool.self, forKey: .preserveMetadata) ?? true
        self.convertToSRGB = try container.decodeIfPresent(Bool.self, forKey: .convertToSRGB) ?? false
    }
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
