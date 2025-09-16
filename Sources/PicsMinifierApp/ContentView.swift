import SwiftUI
import AppKit
import PicsMinifierCore
 
struct ContentView: View {
	@State var appearanceMode: AppearanceMode = .auto
	@State private var systemIsDark: Bool = false
	@State var showDockIcon: Bool = true
	@State var showMenuBarIcon: Bool = true
	@State private var isTargeted: Bool = false
	@State var preset: CompressionPreset = .balanced
	@State var saveMode: SaveMode = .suffix
	@State var previousSaveMode: SaveMode = .suffix
	@State private var confirmOverwrite: Bool = false
	@State var preserveMetadata: Bool = true
	@State var convertToSRGB: Bool = false
	@State var enableGifsicle: Bool = true
	@State var sessionStats: SessionStats = .init()
	@State var showingSettings: Bool = false
	@State var isProcessing: Bool = false

	var body: some View {
		ZStack(alignment: .topTrailing) {
			if showingSettings {
				SimpleSettingsView(
					preset: $preset,
					saveMode: $saveMode,
					preserveMetadata: $preserveMetadata,
					convertToSRGB: $convertToSRGB,
					enableGifsicle: $enableGifsicle,
					appearanceMode: $appearanceMode,
					showDockIcon: $showDockIcon,
					showMenuBarIcon: $showMenuBarIcon
				)
					.transition(.move(edge: .trailing).combined(with: .opacity))
					.zIndex(1)
					.padding(.top, 24)
				Button(action: { showingSettings = false }) {
					Image(systemName: "xmark.circle.fill")
						.symbolRenderingMode(.hierarchical)
						.imageScale(.large)
						.font(.system(size: 18, weight: .semibold))
						.padding(6)
				}
				.buttonStyle(.borderless)
				.help(NSLocalizedString("Закрыть настройки", comment: ""))
				.padding(6)

				// Полупрозрачный оверлей для клика снаружи
				Color.black.opacity(0.08)
					.ignoresSafeArea()
					.onTapGesture { withAnimation { showingSettings = false } }
					.transition(.opacity)
					.zIndex(0)
			} else {
				VStack(spacing: 12) {
					ZStack {
						RoundedRectangle(cornerRadius: 12)
							.stroke(isTargeted ? Color.accentColor : Color.secondary, style: StrokeStyle(lineWidth: 2, dash: [6]))
							.background(
								RoundedRectangle(cornerRadius: 12)
									.fill(Color.secondary.opacity(0.06))
							)
						VStack(spacing: 8) {
							Image(systemName: "tray.and.arrow.down.fill")
								.font(.system(size: 44, weight: .regular))
								.foregroundColor(isTargeted ? .accentColor : .secondary)
							Text(NSLocalizedString("Перетащите сюда файлы или папки", comment: ""))
								.font(.headline)
							Text(NSLocalizedString("или используйте кнопки ниже", comment: ""))
								.font(.caption)
								.foregroundColor(.secondary)
							Text(NSLocalizedString("Поддерживаются: JPEG, PNG, HEIC, GIF", comment: ""))
								.font(.caption2)
								.foregroundColor(.secondary)
						}
						.padding()
					}
					.frame(maxWidth: .infinity, maxHeight: .infinity)
					.onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
						if isProcessing { return false }
						Task { await handleDrop(providers: providers) }
						return true
					}
					.onAppear {
						Task { @MainActor in bindProgressUpdates() }
					}
					.animation(.easeInOut(duration: 0.15), value: isTargeted)

					HStack {
						Text(String(format: NSLocalizedString("Файлов обработано: %lld", comment: ""), sessionStats.processedCount))
						Spacer()
						Text(String(format: NSLocalizedString("Экономия за сессию: %@", comment: ""), ByteCountFormatter.string(fromByteCount: sessionStats.savedBytes, countStyle: .file)))
					}

					if sessionStats.totalInBatch > 0 {
						VStack(alignment: .leading, spacing: 4) {
							ProgressView(value: Double(sessionStats.processedCount), total: Double(sessionStats.totalInBatch)) {
								Text(NSLocalizedString("Прогресс партии", comment: ""))
							}
							Text(String(format: NSLocalizedString("Всего в партии: %lld. Осталось: %lld", comment: ""), sessionStats.totalInBatch, max(0, sessionStats.totalInBatch - sessionStats.processedCount)))
								.font(.caption)
						}
					}

					if isProcessing {
						HStack(spacing: 8) {
							ProgressView().scaleEffect(0.9)
							Text(NSLocalizedString("Идёт обработка…", comment: ""))
								.font(.subheadline)
								.foregroundColor(.secondary)
						}
					}

					Divider()
					HStack(spacing: 8) {
						Button(NSLocalizedString("Выбрать файлы…", comment: "")) { pickFiles() }
							.keyboardShortcut("o", modifiers: [.command])
							.help(NSLocalizedString("Открыть файлы для сжатия (⌘O)", comment: ""))
							.buttonStyle(.borderedProminent)
							.disabled(isProcessing)
						Button(NSLocalizedString("Выбрать папку…", comment: "")) { pickFolder() }
							.keyboardShortcut("O", modifiers: [.command, .shift])
							.help(NSLocalizedString("Выбрать папку для сжатия (⇧⌘O)", comment: ""))
							.buttonStyle(.bordered)
							.disabled(isProcessing)
						Button(NSLocalizedString("Отмена", comment: "")) { ProcessingManager.shared.cancel() }
							.keyboardShortcut(.escape, modifiers: [])
							.help(NSLocalizedString("Отменить текущую партию (Esc)", comment: ""))
							.buttonStyle(.bordered)
							.disabled(!isProcessing)
						Spacer()
					}
					.controlSize(.large)
					HStack {
						Text(String(format: NSLocalizedString("За всё время: файлов — %lld", comment: ""), SafeStatsStore.shared.processedCount()))
						Spacer()
						Text(String(format: NSLocalizedString("Экономия: %@", comment: ""), ByteCountFormatter.string(fromByteCount: SafeStatsStore.shared.totalSavedBytes(), countStyle: .file)))
					}
				}
			}
		}
		.padding(16)
		.frame(width: 600, height: 600)
		.fixedSize()
		.modifier(AppearanceModifier(mode: appearanceMode))
		.onAppear {
			AppUIManager.shared.lockMainWindowSize(width: 600, height: 600)
			AppUIManager.shared.setupWindowPositionAutosave()
			if let raw = UserDefaults.standard.string(forKey: "settings.saveMode"), let mode = SaveMode(rawValue: raw) {
				saveMode = mode; previousSaveMode = mode
			}
			if let rawPreset = UserDefaults.standard.string(forKey: "settings.preset"), let pr = CompressionPreset(rawValue: rawPreset) {
				preset = pr
			}
			preserveMetadata = UserDefaults.standard.object(forKey: "settings.preserveMetadata") as? Bool ?? preserveMetadata
			convertToSRGB = UserDefaults.standard.object(forKey: "settings.convertToSRGB") as? Bool ?? convertToSRGB
			enableGifsicle = UserDefaults.standard.object(forKey: "settings.enableGifsicle") as? Bool ?? enableGifsicle
			if let rawAppearance = UserDefaults.standard.string(forKey: "ui.appearanceMode"),
			   let mode = AppearanceMode(rawValue: rawAppearance) {
				appearanceMode = mode
			} else {
				// Миграция со старой настройки isDark
				let wasIsDark = UserDefaults.standard.object(forKey: "ui.isDark") as? Bool ?? false
				appearanceMode = wasIsDark ? .dark : .light
				UserDefaults.standard.set(appearanceMode.rawValue, forKey: "ui.appearanceMode")
				UserDefaults.standard.removeObject(forKey: "ui.isDark")
			}
			showDockIcon = UserDefaults.standard.object(forKey: "ui.showDockIcon") as? Bool ?? showDockIcon
			showMenuBarIcon = UserDefaults.standard.object(forKey: "ui.showMenuBarIcon") as? Bool ?? showMenuBarIcon
			AppUIManager.shared.setDockIconVisible(showDockIcon)
			AppUIManager.shared.setMenuBarIconVisible(showMenuBarIcon)

			// Инициализируем системную тему
			updateSystemTheme()

			// Добавляем наблюдатель за изменениями системной темы
			DistributedNotificationCenter.default.addObserver(
				forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
				object: nil,
				queue: .main
			) { _ in
				updateSystemTheme()
			}
		}
		.onChange(of: appearanceMode) { newMode in
			print("🎨 onChange appearanceMode: \(newMode)")
			UserDefaults.standard.set(newMode.rawValue, forKey: "ui.appearanceMode")
			// Синхронизируем с NSApp.appearance
			switch newMode {
			case .light:
				print("🎨 Setting light theme")
				NSApp.appearance = NSAppearance(named: .aqua)
			case .dark:
				print("🎨 Setting dark theme")
				NSApp.appearance = NSAppearance(named: .darkAqua)
			case .auto:
				print("🎨 Setting auto theme - clearing NSApp.appearance")
				// Для автоматического режима полностью сбрасываем и обновляем
				NSApp.appearance = nil
				DispatchQueue.main.async {
					print("🎨 Updating all windows for auto theme")
					for window in NSApp.windows {
						window.appearance = nil
						window.invalidateShadow()
						window.contentView?.needsDisplay = true
					}
				}
			}
		}
		.onChange(of: showDockIcon) { newValue in
			UserDefaults.standard.set(newValue, forKey: "ui.showDockIcon")
			AppUIManager.shared.setDockIconVisible(newValue)
		}
		.onChange(of: showMenuBarIcon) { newValue in
			UserDefaults.standard.set(newValue, forKey: "ui.showMenuBarIcon")
			AppUIManager.shared.setMenuBarIconVisible(newValue)
		}
		.onExitCommand { withAnimation { showingSettings = false } }
		.toolbar(content: {
			ToolbarItem(placement: .primaryAction) {
				HStack(spacing: 8) {
					Button(action: {
						withAnimation(.easeInOut(duration: 0.2)) {
							toggleAppearanceMode()
						}
					}) {
						Image(systemName: appearanceModeIcon())
					}
					.help(appearanceModeHelpText())

					Button(action: { showingSettings = true }) {
						Image(systemName: "gearshape")
					}
					.help(NSLocalizedString("Открыть настройки (⌘,)", comment: ""))
				}
			}
		})
	}

	private func resolvedColorScheme() -> ColorScheme? {
		switch appearanceMode {
		case .light:
			return .light
		case .dark:
			return .dark
		case .auto:
			return nil // SwiftUI будет использовать системную тему
		}
	}

	private func toggleAppearanceMode() {
		switch appearanceMode {
		case .auto:
			appearanceMode = .dark
		case .dark:
			appearanceMode = .light
		case .light:
			appearanceMode = .auto
		}
		// НЕ устанавливаем NSApp.appearance здесь - это делает onChange
	}

	private func appearanceModeIcon() -> String {
		switch appearanceMode {
		case .auto:
			return "circle.lefthalf.filled"
		case .dark:
			return "moon.fill"
		case .light:
			return "sun.max.fill"
		}
	}

	private func appearanceModeHelpText() -> String {
		switch appearanceMode {
		case .auto:
			return NSLocalizedString("Текущий режим: Как в системе. Нажмите для переключения на тёмный режим", comment: "")
		case .dark:
			return NSLocalizedString("Текущий режим: Тёмный. Нажмите для переключения на светлый режим", comment: "")
		case .light:
			return NSLocalizedString("Текущий режим: Светлый. Нажмите для переключения на системный режим", comment: "")
		}
	}

	private func updateSystemTheme() {
		let appearance = NSApp.effectiveAppearance
		let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

		if systemIsDark != isDark {
			systemIsDark = isDark

			// Для автоматического режима принудительно обновляем внешний вид приложения
			if appearanceMode == .auto {
				DispatchQueue.main.async {
					NSApp.appearance = nil // Сбрасываем до системного
				}
			}
		}
	}
}


import UniformTypeIdentifiers

struct AppearanceModifier: ViewModifier {
    let mode: AppearanceMode

    func body(content: Content) -> some View {
        switch mode {
        case .light:
            content
                .preferredColorScheme(.light)
                .onAppear { print("🎨 AppearanceModifier: Applied light preferredColorScheme") }
        case .dark:
            content
                .preferredColorScheme(.dark)
                .onAppear { print("🎨 AppearanceModifier: Applied dark preferredColorScheme") }
        case .auto:
            // Для автоматического режима НЕ применяем preferredColorScheme
            // SwiftUI будет следовать системной теме
            content
                .onAppear { print("🎨 AppearanceModifier: Auto mode - no preferredColorScheme") }
        }
    }
}


