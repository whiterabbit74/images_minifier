import AppKit
import SwiftUI
import PicsMinifierCore

final class AppUIManager {
	static let shared = AppUIManager()

	private var statusItem: NSStatusItem?
	private var settingsWindow: NSWindow?
	private init() {}

	func applyAppIcons() {
		// Полностью пустая функция для отладки
		print("✅ applyAppIcons() called successfully")
	}

	private var cachedMenuBarImage: NSImage?
    
    private func loadMenuBarImage() -> NSImage? {
        if let cached = cachedMenuBarImage { return cached }
        
        let bundle = Bundle.main

        // Priority 1: Check for vector PDF icon (copied as compression_icon.pdf)
        if let imgURL = bundle.url(forResource: "compression_icon", withExtension: "pdf"),
           let image = NSImage(contentsOf: imgURL) {
            cachedMenuBarImage = image
            return image
        }
        
        // Priority 2: Check for specific menu bar icon (PNG)
        if let imgURL = bundle.url(forResource: "menu_bar_icon", withExtension: "png"),
           let image = NSImage(contentsOf: imgURL) {
            cachedMenuBarImage = image
            return image
        }

        // Try to load app icon sizes for menu bar - start with smaller sizes
        let iconSizes = ["32", "16", "64", "128"]

        for size in iconSizes {
            if let imgURL = bundle.url(forResource: size, withExtension: "png", subdirectory: "Assets.xcassets/AppIcon.appiconset"),
               let image = NSImage(contentsOf: imgURL) {
                cachedMenuBarImage = image
                return image
            }
        }

        // Fallback: try to load from Resources directory
        for size in iconSizes {
            if let imgURL = bundle.url(forResource: size, withExtension: "png"),
               let image = NSImage(contentsOf: imgURL) {
                cachedMenuBarImage = image
                return image
            }
        }

        // Last fallback: try to get app icon
        if let appIcon = NSApp.applicationIconImage {
            cachedMenuBarImage = appIcon
            return appIcon
        }

        return nil
    }

	private var windowWasVisibleBeforeAccessory = false

	func setDockIconVisible(_ visible: Bool) {
		if visible {
			// Возвращаемся в обычный режим
			NSApp.setActivationPolicy(.regular)

			// Восстанавливаем окно если оно было видно до перехода в accessory режим
			if windowWasVisibleBeforeAccessory {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					if let mainWindow = NSApp.windows.first {
						mainWindow.level = .normal // Возвращаем обычный уровень
						mainWindow.makeKeyAndOrderFront(nil)
						mainWindow.orderFrontRegardless()
					}
				}
				windowWasVisibleBeforeAccessory = false
			}
		} else {
			// Сохраняем состояние видимости главного окна и ссылку на него
			let mainWindow = NSApp.windows.first
			windowWasVisibleBeforeAccessory = mainWindow?.isVisible ?? false

			if windowWasVisibleBeforeAccessory, let window = mainWindow {
				// СНАЧАЛА устанавливаем floating уровень ПЕРЕД переходом в accessory
				window.level = .floating
				window.orderFrontRegardless()
			}

			// Переходим в accessory режим (без иконки в доке)
			NSApp.setActivationPolicy(.accessory)

			// Теперь окно уже защищено floating уровнем и не должно исчезнуть
		}
	}

	func showDockBounce() {
		NSApp.requestUserAttention(.informationalRequest)
	}

	func setMenuBarIconVisible(_ visible: Bool) {
		if visible {
			if statusItem == nil {
				let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
				if let image = loadMenuBarImage() {
					// Оптимальный размер для menu bar (учитывая Retina дисплеи)
					image.size = NSSize(width: 20, height: 20)
					// Template image автоматически адаптируется к светлой/темной теме menu bar
					image.isTemplate = true
					item.button?.image = image
				} else {
					// Fallback эмодзи, если иконка не загрузилась
					item.button?.title = "🗜️"
				}
				let menu = NSMenu()
				let openApp = NSMenuItem(title: NSLocalizedString("Открыть приложение", comment: "Open App"), action: #selector(openMainWindow), keyEquivalent: "o")
				openApp.target = self
				let openSettings = NSMenuItem(title: NSLocalizedString("Открыть настройки…", comment: ""), action: #selector(openSettings), keyEquivalent: ",")
				openSettings.target = self
				let quitItem = NSMenuItem(title: NSLocalizedString("Выйти", comment: ""), action: #selector(quitApp), keyEquivalent: "q")
				quitItem.target = self
				menu.addItem(openApp)
				menu.addItem(openSettings)
				menu.addItem(NSMenuItem.separator())
				menu.addItem(quitItem)
				item.menu = menu
				statusItem = item
			}
		} else {
			if let item = statusItem {
				NSStatusBar.system.removeStatusItem(item)
				statusItem = nil
			}
		}
	}

	func showAboutPanel() {
		let info = Bundle.main.infoDictionary
		let appName = info?["CFBundleName"] as? String ?? "PicsMinifier"
		let version = info?["CFBundleShortVersionString"] as? String ?? ""
		let build = info?["CFBundleVersion"] as? String ?? ""
		var options: [NSApplication.AboutPanelOptionKey: Any] = [
			.applicationName: appName,
			.applicationVersion: version.isEmpty ? build : "\(version) (\(build))"
		]
		if let icon = NSApp.applicationIconImage { options[.applicationIcon] = icon }
		NSApp.orderFrontStandardAboutPanel(options)
	}

	/// Фиксирует размер главного окна и отключает его ресайз.
	func lockMainWindowSize(width: CGFloat, height: CGFloat) {
		guard let window = NSApp.windows.first else { return }
		let size = NSSize(width: width, height: height)
		window.setContentSize(size)
		window.minSize = size
		window.maxSize = size
		var style = window.styleMask
		style.remove(.resizable)
		window.styleMask = style
	}

	/// Настраивает сохранение позиции окна и центрирование при первом запуске
	func setupWindowPositionAutosave(name: String = "MainWindow") {
		guard let window = NSApp.windows.first else { return }
		window.setFrameAutosaveName(name)
		let key = "ui.windowHasSavedFrame.\(name)"
		let wasSaved = UserDefaults.standard.bool(forKey: key)
		if !wasSaved {
			window.center()
			UserDefaults.standard.set(true, forKey: key)
		}
	}

	@objc private func quitApp() {
		NSApp.terminate(nil)
	}

	@objc private func openLogsFolder() {
		let url = AppPaths.logsDirectory()
		NSWorkspace.shared.activateFileViewerSelecting([url])
	}

	@objc private func openCSVLog() {
		let url = AppPaths.logCSVURL()
		NSWorkspace.shared.open(url)
	}

	@objc func openMainWindow() {
		// Принудительно активируем приложение
		NSApp.activate(ignoringOtherApps: true)

		// Показываем главное окно
		if let mainWindow = NSApp.windows.first {
			mainWindow.makeKeyAndOrderFront(nil)
			mainWindow.orderFrontRegardless()
		}
	}

	@objc func openSettings() {
		// Сначала открываем главное окно
		openMainWindow()

		// Отправляем уведомление для открытия настроек
		NotificationCenter.default.post(name: .openSettings, object: nil)
	}
}


