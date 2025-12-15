import SwiftUI
import AppKit
import PicsMinifierCore
import UniformTypeIdentifiers

// MARK: - Main Content View
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
    
    // Custom Settings
    @State var customJpegQuality: Double = 0.82
    @State var customPngLevel: Int = 3
    @State var customAvifQuality: Int = 28
    @State var customAvifSpeed: Int = 4
    


    @State var sessionStats: SessionStats = .init()
    @State var showingSettings: Bool = false
    @State var isProcessing: Bool = false
    @State var currentFileName: String = ""
    @State var progressObserverTokens: [NSObjectProtocol] = []
    @State private var confettiCounter: Int = 0 // Trigger for confetti

    var body: some View {
        mainLayout
            .frame(width: 600, height: 600)
            .modifier(AppearanceModifier(mode: appearanceMode))
            .onAppear(perform: setupApp)
            .onChange(of: appearanceMode, perform: handleAppearanceChange)
            .onChange(of: showDockIcon, perform: updateDockIcon)
            .onChange(of: showMenuBarIcon, perform: updateMenuBarIcon)
            .onChange(of: preset, perform: savePreset)
            .onChange(of: saveMode, perform: saveSaveMode)
            .onChange(of: preserveMetadata, perform: savePreserveMetadata)
            .onChange(of: convertToSRGB, perform: saveConvertToSRGB)
            .onChange(of: enableGifsicle, perform: saveEnableGifsicle)
            .onChange(of: customJpegQuality, perform: saveCustomJpegQuality)
            .onChange(of: customPngLevel, perform: saveCustomPngLevel)
            .onChange(of: customAvifQuality, perform: saveCustomAvifQuality)
            .onChange(of: customAvifSpeed, perform: saveCustomAvifSpeed)
            .onChange(of: isProcessing, perform: handleProcessingChange)
            .onDisappear {
                 Task { @MainActor in teardownProgressUpdates() }
            }
    }

    @ViewBuilder
    var mainLayout: some View {
        ZStack {
            contentStack
            
            if showingSettings {
                 settingsOverlay
            }
            
            ConfettiView(counter: confettiCounter)
        }
    }

    // MARK: - Change Handlers

    private func updateDockIcon(_ val: Bool) {
        UserDefaults.standard.set(val, forKey: "ui.showDockIcon")
        AppUIManager.shared.setDockIconVisible(val)
    }

    private func updateMenuBarIcon(_ val: Bool) {
        UserDefaults.standard.set(val, forKey: "ui.showMenuBarIcon")
        AppUIManager.shared.setMenuBarIconVisible(val)
    }

    private func savePreset(_ val: CompressionPreset) {
        UserDefaults.standard.set(val.rawValue, forKey: "settings.preset")
    }

    private func saveSaveMode(_ val: SaveMode) {
        UserDefaults.standard.set(val.rawValue, forKey: "settings.saveMode")
    }

    private func savePreserveMetadata(_ val: Bool) {
        UserDefaults.standard.set(val, forKey: "settings.preserveMetadata")
    }

    private func saveConvertToSRGB(_ val: Bool) {
        UserDefaults.standard.set(val, forKey: "settings.convertToSRGB")
    }

    private func saveEnableGifsicle(_ val: Bool) {
        UserDefaults.standard.set(val, forKey: "settings.enableGifsicle")
    }

    private func saveCustomJpegQuality(_ val: Double) {
        UserDefaults.standard.set(val, forKey: "settings.customJpegQuality")
    }

    private func saveCustomPngLevel(_ val: Int) {
        UserDefaults.standard.set(val, forKey: "settings.customPngLevel")
    }

    private func saveCustomAvifQuality(_ val: Int) {
        UserDefaults.standard.set(val, forKey: "settings.customAvifQuality")
    }

    private func saveCustomAvifSpeed(_ val: Int) {
        UserDefaults.standard.set(val, forKey: "settings.customAvifSpeed")
    }

    private func handleProcessingChange(_ processing: Bool) {
        if !processing && sessionStats.totalInBatch > 0 && sessionStats.failedFiles == 0 {
            // Success! Trigger confetti
            confettiCounter += 1
        }
    }

    // MARK: - Logic & Actions

    @ViewBuilder
    private var contentStack: some View {
        ZStack {
            // Background Gradient
            AmbientBackground()

            // Main Content
            mainContent
                .blur(radius: showingSettings ? 10 : 0)
                .scaleEffect(showingSettings ? 0.95 : 1)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            headerView
            centerView
            footerView
            globalStatsView
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Spacer()
            HStack(spacing: 12) {
                ThemeToggleButton(appearanceMode: $appearanceMode, toggleAction: toggleAppearanceMode)
                SettingsButton(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showingSettings = true } })
            }
            .padding(.top, 16)
            .padding(.trailing, 16)
        }
    }

    @ViewBuilder
    private var centerView: some View {
        ZStack {
            if isProcessing || sessionStats.totalInBatch > 0 {
                 ProcessingView(stats: sessionStats, isProcessing: isProcessing, currentFileName: currentFileName)
                     .transition(.opacity)
            } else {
                DropZoneView(isTargeted: isTargeted)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            if isProcessing { return false }
            Task { await handleDrop(providers: providers) }
            return true
        }
    }

    @ViewBuilder
    private var footerView: some View {
        Group {
            if !isProcessing && sessionStats.totalInBatch == 0 {
                ActionButtonsFooter(
                    pickFiles: pickFiles,
                    pickFolder: pickFolder
                )
            } else if isProcessing {
                 Button(NSLocalizedString("Отмена", comment: "")) { NotificationCenter.default.post(name: .cancelProcessing, object: nil) }
                    .buttonStyle(GlassButtonStyle(color: .red))
            } else {
                 Button(NSLocalizedString("Готово", comment: "")) {
                     withAnimation {
                          // Reset stats for new batch
                          sessionStats = .init()
                     }
                 }
                 .buttonStyle(GlassButtonStyle(color: .green))
            }
        }
        .padding(.bottom, 24)
    }

    @ViewBuilder
    private var globalStatsView: some View {
        GlobalStatsFooter()
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
    }

    @ViewBuilder
    private var settingsOverlay: some View {
        Color.black.opacity(0.2)
            .ignoresSafeArea()
            .onTapGesture { withAnimation { showingSettings = false } }
            .transition(.opacity)

        SimpleSettingsView(
            preset: $preset,
            saveMode: $saveMode,
            preserveMetadata: $preserveMetadata,
            convertToSRGB: $convertToSRGB,
            enableGifsicle: $enableGifsicle,
            appearanceMode: $appearanceMode,
            showDockIcon: $showDockIcon,
            showMenuBarIcon: $showMenuBarIcon,
            customJpegQuality: $customJpegQuality,
            customPngLevel: $customPngLevel,
            customAvifQuality: $customAvifQuality,
            customAvifSpeed: $customAvifSpeed
        )
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.2), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { withAnimation { showingSettings = false } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(12)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .transition(.opacity)
        .zIndex(1)
    }

    private func setupApp() {
        AppUIManager.shared.lockMainWindowSize(width: 600, height: 600)
        AppUIManager.shared.setupWindowPositionAutosave()
        loadPreferences()
        updateSystemTheme()

        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in updateSystemTheme() }

        Task { @MainActor in bindProgressUpdates() }
    }

    private func loadPreferences() {
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
        }
        showDockIcon = UserDefaults.standard.object(forKey: "ui.showDockIcon") as? Bool ?? showDockIcon
        showMenuBarIcon = UserDefaults.standard.object(forKey: "ui.showMenuBarIcon") as? Bool ?? showMenuBarIcon
        
        customJpegQuality = UserDefaults.standard.double(forKey: "settings.customJpegQuality")
        if customJpegQuality == 0 { customJpegQuality = 0.82 }
        
        customPngLevel = UserDefaults.standard.integer(forKey: "settings.customPngLevel")
        if customPngLevel == 0 { customPngLevel = 3 }
        
        customAvifQuality = UserDefaults.standard.integer(forKey: "settings.customAvifQuality")
        if customAvifQuality == 0 { customAvifQuality = 28 }
        
        customAvifSpeed = UserDefaults.standard.integer(forKey: "settings.customAvifSpeed")
        if customAvifSpeed == 0 { customAvifSpeed = 4 }

        AppUIManager.shared.setDockIconVisible(showDockIcon)
        AppUIManager.shared.setMenuBarIconVisible(showMenuBarIcon)
    }

    private func handleAppearanceChange(newMode: AppearanceMode) {
        UserDefaults.standard.set(newMode.rawValue, forKey: "ui.appearanceMode")
        switch newMode {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            NSApp.appearance = nil
            DispatchQueue.main.async { for w in NSApp.windows { w.appearance = nil } }
        }
    }

    private func toggleAppearanceMode() {
        withAnimation {
            switch appearanceMode {
            case .auto: appearanceMode = .dark
            case .dark: appearanceMode = .light
            case .light: appearanceMode = .auto
            }
        }
    }

    private func updateSystemTheme() {
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if systemIsDark != isDark {
            systemIsDark = isDark
            if appearanceMode == .auto {
                DispatchQueue.main.async { NSApp.appearance = nil }
            }
        }
    }
}

// MARK: - Subviews

struct AmbientBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // Base background
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()

            // Subtle gradient blobs
            GeometryReader { proxy in
                let w = proxy.size.width
                let h = proxy.size.height
                
                EllipticalGradient(
                    colors: [Color.accentColor.opacity(0.1), .clear],
                    center: .topLeading,
                    startRadiusFraction: 0.0,
                    endRadiusFraction: 0.5
                )
                .frame(width: w, height: h)
                .offset(x: -w/4, y: -h/4)

                EllipticalGradient(
                    colors: [Color.blue.opacity(0.05), .clear],
                    center: .bottomTrailing,
                    startRadiusFraction: 0.0,
                    endRadiusFraction: 0.6
                )
                .frame(width: w, height: h)
                .offset(x: w/4, y: h/4)
            }
        }
    }
}

struct DropZoneView: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                // Glow effect backing
                Circle()
                    .fill(Color.accentColor.opacity(isTargeted ? 0.4 : 0.0))
                    .frame(width: 160, height: 160)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 0.3), value: isTargeted)

                // Main Icon
                Image(systemName: "arrow.down.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isTargeted ? .white : .secondary)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    // Bounce animation when targeted
                    .scaleEffect(isTargeted ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isTargeted)
            }

            VStack(spacing: 8) {
                Text(NSLocalizedString("Перетащите файлы сюда", comment: "Drop files here"))
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(NSLocalizedString("Поддерживаются: JPEG, PNG, HEIC, GIF", comment: "Supported formats"))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding(40)
        // Glass border
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
                .padding(40)
        )
         // Subtle shadow for the card
        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
    }
}

struct ActionButtonsFooter: View {
    var pickFiles: () -> Void
    var pickFolder: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: pickFiles) {
                Label(NSLocalizedString("Выбрать файлы", comment: ""), systemImage: "doc.on.doc")
                    .frame(minWidth: 140)
            }
            .buttonStyle(GlassButtonStyle(color: .accentColor))

            Button(action: pickFolder) {
                Label(NSLocalizedString("Выбрать папку", comment: ""), systemImage: "folder")
                    .frame(minWidth: 140)
            }
            .buttonStyle(GlassButtonStyle(color: .secondary))
        }
    }
}

struct GlobalStatsFooter: View {
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: NSLocalizedString("Файлов: %lld", comment: ""), SafeStatsStore.shared.processedCount()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "externaldrive")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: NSLocalizedString("Сэкономлено: %@", comment: ""), ByteCountFormatter.string(fromByteCount: SafeStatsStore.shared.totalSavedBytes(), countStyle: .file)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Styles & Components

struct GlassButtonStyle: ButtonStyle {
    var color: Color

    @Environment(\.isEnabled) var isEnabled
    @Environment(\.colorScheme) var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                ZStack {
                    if color == .secondary {
                        Rectangle().fill(.regularMaterial)
                    } else {
                        color.opacity(configuration.isPressed ? 0.6 : 0.8)
                    }
                }
            )
            .background(
                color == .secondary ? Color.clear : color.opacity(0.2)
            )
            .foregroundStyle(color == .secondary ? Color.primary : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                 RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

struct ThemeToggleButton: View {
    @Binding var appearanceMode: AppearanceMode
    var toggleAction: () -> Void

    var body: some View {
        Button(action: toggleAction) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(helpText)
    }

    private var iconName: String {
        switch appearanceMode {
        case .auto: return "circle.lefthalf.filled"
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        }
    }

    private var helpText: String {
        switch appearanceMode {
        case .auto: return NSLocalizedString("Нажать для тёмной темы", comment: "")
        case .dark: return NSLocalizedString("Нажать для светлой темы", comment: "")
        case .light: return NSLocalizedString("Нажать для авто темы", comment: "")
        }
    }
}

struct SettingsButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(NSLocalizedString("Настройки", comment: ""))
    }
}

// MARK: - Processing View
// Adapted from previous ProgressSummaryView but modernized
struct ProcessingView: View {
    let stats: SessionStats
    let isProcessing: Bool
    let currentFileName: String
    @State private var isRotating: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            // Animated Icon Status
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                
                if isProcessing {
                    // Spinning outer ring
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(statusColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                isRotating = true
                            }
                        }
                } else {
                     Image(systemName: statusIcon)
                        .font(.system(size: 40))
                        .foregroundStyle(statusColor)
                }
            }

            VStack(spacing: 8) {
                Text(statusTitle)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(statusSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    
                ZStack {
                    if isProcessing && !currentFileName.isEmpty {
                        Text(currentFileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .truncationMode(.middle)
                            .frame(maxWidth: 300)
                            .id(currentFileName)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .offset(y: 10)),
                                removal: .opacity.combined(with: .offset(y: -10))
                            ))
                    }
                }
                .frame(height: 20)
                .clipped()
                .animation(.easeInOut(duration: 0.25), value: currentFileName)
            }

            // Modern Progress Bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 8)
                        
                        Capsule()
                            .fill(statusColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 8)
                            .animation(.spring(), value: progress)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)
                
                HStack {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(stats.processedFiles) / \(stats.totalInBatch)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 40)
            }
            .padding(.top, 10)

            // Grid Stats
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatPip(title: "ЭКОНОМИЯ", value: ByteCountFormatter.string(fromByteCount: stats.savedBytes, countStyle: .file))
                StatPip(title: "УСПЕШНО", value: "\(stats.successfulFiles)")
                StatPip(title: "ПРОПУЩЕНО", value: "\(stats.skippedFiles)")
                StatPip(title: "ОШИБКИ", value: "\(stats.failedFiles)", isError: stats.failedFiles > 0)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .padding(40)
        // Glass border matching DropZoneView
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .strokeBorder(LinearGradient(
                    colors: [.white.opacity(0.5), .white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
                .padding(40)
        )
        // Subtle shadow matching DropZoneView
        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 10)
    }

    var progress: Double {
        guard stats.totalInBatch > 0 else { return 0 }
        return Double(stats.processedFiles) / Double(stats.totalInBatch)
    }

    var statusColor: Color {
        if isProcessing { return .accentColor }
        if stats.failedFiles > 0 { return .red }
        return .green
    }

    var statusIcon: String {
        if isProcessing { return "gearshape.2.fill" }
        if stats.failedFiles > 0 { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    var statusTitle: String {
        if isProcessing { return NSLocalizedString("Сжатие...", comment: "") }
        if stats.failedFiles > 0 { return NSLocalizedString("Завершено с ошибками", comment: "") }
        return NSLocalizedString("Готово!", comment: "")
    }

    var statusSubtitle: String {
        if isProcessing { return NSLocalizedString("Пожалуйста, подождите", comment: "") }
        return NSLocalizedString("Все задачи выполнены", comment: "")
    }
}

struct StatPip: View {
    let title: String
    let value: String
    var isError: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(isError ? .red : .primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
}

struct AppearanceModifier: ViewModifier {
    let mode: AppearanceMode
    func body(content: Content) -> some View {
        content.preferredColorScheme(mode.preferredColorScheme)
    }
}

private extension AppearanceMode {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil
        }
    }
}
