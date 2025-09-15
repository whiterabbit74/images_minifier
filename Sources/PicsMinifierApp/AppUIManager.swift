import AppKit
import SwiftUI
import PicsMinifierCore

final class AppUIManager {
	static let shared = AppUIManager()

	private var statusItem: NSStatusItem?
	private var settingsWindow: NSWindow?
	private init() {}

	func applyAppIcons() {
		let bundle = Bundle.module
		if let fallbackURL = bundle.url(forResource: "appstore", withExtension: "png", subdirectory: "AppIcons"),
		   let image = NSImage(contentsOf: fallbackURL) {
			NSApp.applicationIconImage = image
			return
		}
		if let dockURL = bundle.url(forResource: "512", withExtension: "png", subdirectory: "AppIcons/Assets.xcassets/AppIcon.appiconset"),
		   let image = NSImage(contentsOf: dockURL) {
			NSApp.applicationIconImage = image
		}
	}

	private func loadMenuBarImage() -> NSImage? {
		let bundle = Bundle.module
		if let imgURL = bundle.url(forResource: "appstore", withExtension: "png", subdirectory: "AppIcons"),
		   let image = NSImage(contentsOf: imgURL) {
			return image
		}
		if let imgURL = bundle.url(forResource: "32", withExtension: "png", subdirectory: "AppIcons/Assets.xcassets/AppIcon.appiconset") {
			return NSImage(contentsOf: imgURL)
		}
		return nil
	}

	func setDockIconVisible(_ visible: Bool) {
		NSApp.setActivationPolicy(visible ? .regular : .accessory)
	}

	func showDockBounce() {
		NSApp.requestUserAttention(.informationalRequest)
	}

	func setMenuBarIconVisible(_ visible: Bool) {
		if visible {
			if statusItem == nil {
				let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
				if let image = loadMenuBarImage() {
					image.size = NSSize(width: 18, height: 18)
					image.isTemplate = true
					item.button?.image = image
				} else {
					item.button?.title = "🗜️"
				}
				let menu = NSMenu()
				let openSettings = NSMenuItem(title: NSLocalizedString("Открыть настройки…", comment: ""), action: #selector(openSettings), keyEquivalent: ",")
				openSettings.target = self
				let openLogs = NSMenuItem(title: NSLocalizedString("Открыть папку логов", comment: ""), action: #selector(openLogsFolder), keyEquivalent: "l")
				openLogs.target = self
				let openCSV = NSMenuItem(title: NSLocalizedString("Открыть CSV лог", comment: ""), action: #selector(openCSVLog), keyEquivalent: "h")
				openCSV.target = self
				let quitItem = NSMenuItem(title: NSLocalizedString("Выйти", comment: ""), action: #selector(quitApp), keyEquivalent: "q")
				quitItem.target = self
				menu.addItem(openSettings)
				menu.addItem(openLogs)
				menu.addItem(openCSV)
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

	@objc func openSettings() {
		NotificationCenter.default.post(name: .openSettings, object: nil)
	}
}


