import Foundation

public enum AppPaths {
	public static func logsDirectory() -> URL {
		let fm = FileManager.default
		let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
		let dir = base.appendingPathComponent("PicsMinifier", isDirectory: true)
		try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
		return dir
	}

	public static func logCSVURL() -> URL {
		logsDirectory().appendingPathComponent("history.csv")
	}
}


