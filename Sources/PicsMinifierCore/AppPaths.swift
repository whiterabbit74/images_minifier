import Foundation

public enum AppPaths {
	public static func logsDirectory() -> URL {
		let fm = FileManager.default

		// Safe access to application support directory with fallback
		guard let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
			// Fallback to temporary directory if application support is unavailable
			let tempDir = fm.temporaryDirectory.appendingPathComponent("PicsMinifier", isDirectory: true)
			try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
			return tempDir
		}

		let dir = base.appendingPathComponent("PicsMinifier", isDirectory: true)
		try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir
	}

	public static func logCSVURL() -> URL {
		logsDirectory().appendingPathComponent("history.csv")
	}
}


