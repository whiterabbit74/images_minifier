import SwiftUI
import AppKit
import PicsMinifierCore

@main
struct PicsMinifierMainApp: App {
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
		#if os(macOS)
		.commands {
			CommandGroup(replacing: .newItem) {
				Button(NSLocalizedString("Open Files…", comment: "")) { NotificationCenter.default.post(name: .openFiles, object: nil) }
					.keyboardShortcut("o", modifiers: [.command])
				Button(NSLocalizedString("Open Folder…", comment: "")) { NotificationCenter.default.post(name: .openFolder, object: nil) }
					.keyboardShortcut("O", modifiers: [.command, .shift])
				Divider()
				Button(NSLocalizedString("Cancel", comment: "")) { NotificationCenter.default.post(name: .cancelProcessing, object: nil) }
					.keyboardShortcut(.escape, modifiers: [])
			}

			// Clean up irrelevant standard items
			CommandGroup(replacing: .saveItem) { }
			CommandGroup(replacing: .printItem) { }

			CommandGroup(replacing: .appInfo) {
				Button(NSLocalizedString("About PicsMinifier", comment: "")) { AppUIManager.shared.showAboutPanel() }
			}

			CommandGroup(replacing: .appSettings) {
				Button(NSLocalizedString("Settings…", comment: "")) { AppUIManager.shared.openSettings() }
					.keyboardShortcut(",", modifiers: [.command])
			}
		}
		#endif
	}

	init() {
		// Initialize language
		let languageRaw = UserDefaults.standard.string(forKey: "ui.language") ?? AppLanguage.auto.rawValue
		if let language = AppLanguage(rawValue: languageRaw) {
			LanguageManager.shared.applyLanguage(language)
		}

		// Initialize crash logger
		CrashLogger.shared.logInfo("Application starting", context: "AppMain")

		// Disable icons completely to fix crashes
		// DispatchQueue.main.async {
		//     AppUIManager.shared.applyAppIcons()
		//     CrashLogger.shared.logInfo("App icons applied", context: "AppMain")
		// }
		CrashLogger.shared.logInfo("App icons disabled to prevent crashes", context: "AppMain")

		// Reset CSV log and start fresh with new format
                let logURL = AppPaths.logCSVURL()
                if CSVLogger(logURL: logURL) == nil {
                        CrashLogger.shared.logError("Failed to initialize CSV logger", context: "AppMain")
                }
		// Bind progress update
		Task { @MainActor in
			let dummyView = ContentView()
			// Trigger to register observer. In production code bind in onAppear
			_ = dummyView
		}
		// Set path to embedded libwebp.dylib if present
		if ProcessInfo.processInfo.environment["PICS_LIBWEBP_PATH"] == nil {
			if let libURL = Bundle.main.url(forResource: "libwebp", withExtension: "dylib") {
				setenv("PICS_LIBWEBP_PATH", libURL.path, 1)
			}
		}
	}
}


