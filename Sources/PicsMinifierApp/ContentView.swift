import SwiftUI
import AppKit
import PicsMinifierCore
 
struct ContentView: View {
	@State var appearanceMode: AppearanceMode = .auto
	@State private var currentColorScheme: ColorScheme?
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
				SettingsView()
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
						Text(String(format: NSLocalizedString("За всё время: файлов — %lld", comment: ""), StatsStore.shared.allTimeProcessedCount))
						Spacer()
						Text(String(format: NSLocalizedString("Экономия: %@", comment: ""), ByteCountFormatter.string(fromByteCount: StatsStore.shared.allTimeSavedBytes, countStyle: .file)))
					}
				}
			}
		}
		.padding(16)
		.frame(width: 600, height: 600)
		.fixedSize()
		.preferredColorScheme(resolvedColorScheme())
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
		}
		.onChange(of: appearanceMode) { UserDefaults.standard.set($0.rawValue, forKey: "ui.appearanceMode") }
		.onChange(of: showDockIcon) { UserDefaults.standard.set($0, forKey: "ui.showDockIcon") }
		.onChange(of: showMenuBarIcon) { UserDefaults.standard.set($0, forKey: "ui.showMenuBarIcon") }
		.onExitCommand { withAnimation { showingSettings = false } }
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button(action: { showingSettings = true }) {
					Image(systemName: "gearshape")
				}
				.help(NSLocalizedString("Открыть настройки (⌘,)", comment: ""))
			}
		}
	}

	private func resolvedColorScheme() -> ColorScheme? {
		switch appearanceMode {
		case .light:
			return .light
		case .dark:
			return .dark
		case .auto:
			return nil // Позволяет системе определить тему автоматически
		}
	}
}

struct SessionStats {
	var processedCount: Int = 0
	var savedBytes: Int64 = 0
	var totalInBatch: Int = 0
}

import UniformTypeIdentifiers


