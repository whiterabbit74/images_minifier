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
	@State var progressObserverTokens: [NSObjectProtocol] = []

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

				// Background overlay - no click to close
				Color.black.opacity(0.08)
					.allowsHitTesting(false)
					.ignoresSafeArea()
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

					ProgressSummaryView(stats: sessionStats, isProcessing: isProcessing)
						.padding(.vertical, 4)

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
			UserDefaults.standard.set(newMode.rawValue, forKey: "ui.appearanceMode")
			// Theme switching - let SwiftUI handle auto mode
			switch newMode {
			case .light:
				NSApp.appearance = NSAppearance(named: .aqua)
			case .dark:
				NSApp.appearance = NSAppearance(named: .darkAqua)
			case .auto:
				// Clear NSApp.appearance to follow system theme
				NSApp.appearance = nil
				// Force SwiftUI to re-evaluate theme
				DispatchQueue.main.async {
					for window in NSApp.windows {
						window.appearance = nil
					}
				}
			}
		}
                .onChange(of: showDockIcon) { newValue in
                        UserDefaults.standard.set(newValue, forKey: "ui.showDockIcon")
                        AppUIManager.shared.setDockIconVisible(newValue)
                }
                .onDisappear {
                        Task { @MainActor in teardownProgressUpdates() }
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


private struct ProgressSummaryView: View {
    let stats: SessionStats
    let isProcessing: Bool

    private var hasActiveBatch: Bool { stats.totalInBatch > 0 }
    private var clampedProgress: Double {
        guard hasActiveBatch else { return 0 }
        let value = Double(stats.processedFiles) / Double(max(stats.totalInBatch, 1))
        return min(max(value, 0), 1)
    }

    private var percentText: String {
        let percent = Int(round(clampedProgress * 100))
        return "\(percent)%"
    }

    private var remainingCount: Int {
        max(stats.totalInBatch - stats.processedFiles, 0)
    }

    private var headerIconName: String {
        if hasErrors && !isProcessing {
            return "exclamationmark.triangle.fill"
        } else if isComplete {
            return "checkmark.circle.fill"
        } else if isProcessing {
            return "arrow.triangle.2.circlepath.circle.fill"
        } else if hasActiveBatch {
            return "pause.circle.fill"
        } else {
            return "tray.and.arrow.down"
        }
    }

    private var headerColor: Color {
        if hasErrors && !isProcessing {
            return .orange
        } else if isComplete {
            return .green
        } else if isProcessing {
            return .accentColor
        } else if hasActiveBatch {
            return .orange
        } else {
            return .secondary
        }
    }

    private var headerTitle: String {
        if hasErrors && !isProcessing {
            return NSLocalizedString("Сжатие завершено с ошибками", comment: "")
        } else if isComplete {
            return NSLocalizedString("Сжатие завершено", comment: "")
        } else if isProcessing {
            return NSLocalizedString("Идёт сжатие", comment: "")
        } else if hasActiveBatch {
            return NSLocalizedString("Пауза", comment: "")
        } else {
            return NSLocalizedString("Файлы ещё не выбраны", comment: "")
        }
    }

    private var isComplete: Bool {
        hasActiveBatch && stats.processedFiles >= stats.totalInBatch && !isProcessing
    }

    private var hasErrors: Bool {
        stats.failedFiles > 0
    }

    private var savedBytesText: String {
        ByteCountFormatter.string(fromByteCount: stats.savedBytes, countStyle: .file)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: headerIconName)
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(headerColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.headline)

                    Text(statusSubtitle())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if hasActiveBatch {
                    Text(percentText)
                        .monospacedDigit()
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isComplete ? .green : .primary)
                }
            }

            ProgressBar(progress: clampedProgress, isComplete: isComplete)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 16) {
                    InfoChip(title: NSLocalizedString("В партии", comment: ""), value: "\(stats.totalInBatch)")
                    InfoChip(title: NSLocalizedString("Обработано", comment: ""), value: "\(stats.processedFiles)")
                    InfoChip(title: NSLocalizedString("Осталось", comment: ""), value: hasActiveBatch ? "\(remainingCount)" : "—")
                    InfoChip(title: NSLocalizedString("Экономия", comment: ""), value: savedBytesText)
                }

                HStack(spacing: 16) {
                    InfoChip(title: NSLocalizedString("Успешно", comment: ""), value: "\(stats.successfulFiles)")
                    InfoChip(title: NSLocalizedString("Пропущено", comment: ""), value: "\(stats.skippedFiles)")
                    InfoChip(title: NSLocalizedString("Ошибки", comment: ""), value: "\(stats.failedFiles)")
                }
            }
            .font(.caption)

            if isComplete {
                Text(NSLocalizedString("Все файлы успешно обработаны", comment: ""))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if isProcessing {
                Text(NSLocalizedString("Не закрывайте приложение до завершения процесса", comment: ""))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else if !hasActiveBatch {
                Text(NSLocalizedString("Перетащите файлы или выберите их кнопками ниже, чтобы начать", comment: ""))
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        )
        .animation(.easeInOut(duration: 0.2), value: stats.processedFiles)
        .animation(.easeInOut(duration: 0.2), value: isProcessing)
    }

    private func statusSubtitle() -> String {
        if hasActiveBatch {
            return String(format: NSLocalizedString("Обработано: %lld из %lld • Ошибок: %lld", comment: ""), stats.processedFiles, stats.totalInBatch, stats.failedFiles)
        } else {
            return NSLocalizedString("Готово к запуску", comment: "")
        }
    }
}

private struct ProgressBar: View {
    var progress: Double
    var isComplete: Bool

    private let height: CGFloat = 14

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.secondary.opacity(0.2))

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(isComplete ? Color.green : Color.accentColor)
                    .frame(width: max(height, proxy.size.width * CGFloat(min(max(progress, 0), 1))))
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: height)
    }
}

private struct InfoChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundColor(.primary)
        }
    }
}


import UniformTypeIdentifiers

struct AppearanceModifier: ViewModifier {
    let mode: AppearanceMode

    func body(content: Content) -> some View {
        switch mode {
        case .light:
            content.preferredColorScheme(.light)
        case .dark:
            content.preferredColorScheme(.dark)
        case .auto:
            // Auto mode follows system theme
            content
        }
    }
}
