import Foundation

public enum AppPaths {
        public static func logsDirectory() -> URL {
                let fm = FileManager.default

                let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                        ?? fm.temporaryDirectory

                let appSupport = base.appendingPathComponent("PicsMinifier", isDirectory: true)
                let logsDir = appSupport.appendingPathComponent("Logs", isDirectory: true)

                try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)

                return logsDir
        }

        public static func logCSVURL() -> URL {
                logsDirectory().appendingPathComponent("compression_log.csv")
        }
}


