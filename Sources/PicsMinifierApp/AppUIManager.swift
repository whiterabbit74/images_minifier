import AppKit
import SwiftUI
import PicsMinifierCore
import UserNotifications
import ServiceManagement

final class AppUIManager {
	static let shared = AppUIManager()

	private var statusItem: NSStatusItem?
	private var settingsWindow: NSWindow?
	private init() {}

    func applyAppearance(_ mode: AppearanceMode) {
        // Enforce appearance on the main thread
        if Thread.isMainThread {
            self._applyAppearance(mode)
        } else {
            DispatchQueue.main.async {
                self._applyAppearance(mode)
            }
        }
    }

    private func _applyAppearance(_ mode: AppearanceMode) {
        switch mode {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            NSApp.appearance = nil
            // Critical: We must iterate all windows and reset their appearance to nil so they inherit from system
            for window in NSApp.windows {
                window.appearance = nil
                window.contentView?.needsDisplay = true
            }
        }
    }
    
	func applyAppIcons() {
		// Completely empty function for debugging
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
			// Switch back to regular mode
			NSApp.setActivationPolicy(.regular)

			// Restore window if it was visible before entering accessory mode
			if windowWasVisibleBeforeAccessory {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
					if let mainWindow = NSApp.windows.first {
						mainWindow.level = .normal // Restore normal level
						mainWindow.makeKeyAndOrderFront(nil)
						mainWindow.orderFrontRegardless()
					}
				}
				windowWasVisibleBeforeAccessory = false
			}
		} else {
			// Save main window visibility state
			let mainWindow = NSApp.windows.first
			windowWasVisibleBeforeAccessory = mainWindow?.isVisible ?? false

			if windowWasVisibleBeforeAccessory, let window = mainWindow {
				// FIRST set floating level BEFORE switching to accessory
				window.level = .floating
				window.orderFrontRegardless()
			}

			// Switch to accessory mode (no dock icon)
			NSApp.setActivationPolicy(.accessory)

			// Window is now protected by floating level and should not disappear
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
                    // Optimal size for menu bar (considering Retina displays)
                    image.size = NSSize(width: 18, height: 18) // Slightly smaller for better fit
                    // Template image automatically adapts to light/dark menu bar theme
                    image.isTemplate = true
                    item.button?.image = image
                } else {
                    // Fallback to SF Symbol which looks much better than emoji
                    if let image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "PicsMinifier") {
                         image.isTemplate = true
                         item.button?.image = image
                    } else {
                         item.button?.title = "PM"
                    }
                }
				let menu = NSMenu()
				let openApp = NSMenuItem(title: NSLocalizedString("Open App", comment: "Open App"), action: #selector(openMainWindow), keyEquivalent: "o")
				openApp.target = self
				let openSettings = NSMenuItem(title: NSLocalizedString("Open Settings…", comment: ""), action: #selector(openSettings), keyEquivalent: ",")
				openSettings.target = self
				let quitItem = NSMenuItem(title: NSLocalizedString("Quit", comment: ""), action: #selector(quitApp), keyEquivalent: "q")
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

	/// Locks main window size and disables resizing
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

	/// Configures window position autosave and centering on first launch
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
		// Force activate app
		NSApp.activate(ignoringOtherApps: true)

		// Show main window
		if let mainWindow = NSApp.windows.first {
			mainWindow.makeKeyAndOrderFront(nil)
			mainWindow.orderFrontRegardless()
		}
	}

	@objc func openSettings() {
		// Open main window first
		openMainWindow()

		// Post notification to open settings
		NotificationCenter.default.post(name: .openSettings, object: nil)
	}
    func setLaunchAtLogin(_ enabled: Bool) {
        // Simple Main Bundle ID check for standard apps
        // For sandboxed apps, this usually requires a helper login item.
        // We will try SMAppService if available (macOS 13+), else fallback to LSSharedFileList logic shim or no-op log
        
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        } else {
            // Fallback or legacy (not implemented for this audit context to avoid complexity)
            print("Launch at login requires macOS 13+ or helper app for this codebase context.")
        }
    }

    func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}


