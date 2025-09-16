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
			CommandMenu(NSLocalizedString("Файл", comment: "")) {
				Button(NSLocalizedString("Выбрать файлы…", comment: "")) { NotificationCenter.default.post(name: .openFiles, object: nil) }
					.keyboardShortcut("o", modifiers: [.command])
				Button(NSLocalizedString("Выбрать папку…", comment: "")) { NotificationCenter.default.post(name: .openFolder, object: nil) }
					.keyboardShortcut("O", modifiers: [.command, .shift])
				Divider()
				Button(NSLocalizedString("Отмена", comment: "")) { NotificationCenter.default.post(name: .cancelProcessing, object: nil) }
					.keyboardShortcut(.escape, modifiers: [])
			}

			CommandGroup(replacing: .appInfo) {
				Button(NSLocalizedString("О программе PicsMinifier", comment: "")) { AppUIManager.shared.showAboutPanel() }
			}

			CommandGroup(replacing: .appSettings) {
				Button(NSLocalizedString("Настройки…", comment: "")) { AppUIManager.shared.openSettings() }
					.keyboardShortcut(",", modifiers: [.command])
			}
		}
		#endif
	}

	init() {
		// Инициализируем crash logger
		CrashLogger.shared.logInfo("Application starting", context: "AppMain")

		// Отключаем иконки полностью для исправления крашей
		// DispatchQueue.main.async {
		//     AppUIManager.shared.applyAppIcons()
		//     CrashLogger.shared.logInfo("App icons applied", context: "AppMain")
		// }
		CrashLogger.shared.logInfo("App icons disabled to prevent crashes", context: "AppMain")

		// Сбросим CSV-лог и начнём заново с новым форматом
		let logURL = AppPaths.logCSVURL()
		try? FileManager.default.removeItem(at: logURL)
		_ = CSVLogger(logURL: logURL)
		// Привяжем обновление прогресса
		Task { @MainActor in
			let dummyView = ContentView()
			// Тригер для регистрации наблюдателя. В рабочем коде биндим в onAppear
			_ = dummyView
		}
		// Установим путь до встроенной libwebp.dylib при наличии
		if ProcessInfo.processInfo.environment["PICS_LIBWEBP_PATH"] == nil {
			if let libURL = Bundle.main.url(forResource: "libwebp", withExtension: "dylib") {
				setenv("PICS_LIBWEBP_PATH", libURL.path, 1)
			}
		}
	}
}


