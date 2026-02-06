import SwiftUI
import AppKit
import PicsMinifierCore
import UniformTypeIdentifiers

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var sessionStore = SessionStore()
    
    @State private var isTargeted: Bool = false
    @State private var confirmOverwrite: Bool = false
    @State var showingSettings: Bool = false // Keeping for now, will replace with Sidebar later
    @State var progressObserverTokens: [NSObjectProtocol] = []
    @State private var confettiCounter: Int = 0 // Trigger for confetti
    @State private var currentTab: AppTab = .optimizer

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(settingsStore: settingsStore)
            
            Divider()
                .background(Color.proBorder)
            
            mainContent
        }
        .id(settingsStore.appearanceMode) // Critical: Force full view hierarchy rebuild on theme change
        .contentShape(Rectangle())
        .onDrop(of: [.item, .fileURL, .url, .text], delegate: AppDropDelegate(sessionStore: sessionStore, settingsStore: settingsStore, isTargeted: $isTargeted, currentTab: $currentTab))
        .onDrop(of: [.item, .fileURL, .url, .text], delegate: AppDropDelegate(sessionStore: sessionStore, settingsStore: settingsStore, isTargeted: $isTargeted, currentTab: $currentTab))
        .frame(minWidth: 600, minHeight: 450)
        .onAppear(perform: setupApp)
        .onChange(of: settingsStore.showDockIcon, perform: updateDockIcon)
        .onChange(of: settingsStore.showMenuBarIcon, perform: updateMenuBarIcon)
        .onChange(of: sessionStore.isProcessing) { processing in
            if !processing && sessionStore.stats.totalInBatch > 0 && sessionStore.stats.failedFiles == 0 {
                confettiCounter += 1
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top Toolbar
            HStack(spacing: 16) {
                // Left: Tabs
                HStack(spacing: 4) {
                    TabButton(title: NSLocalizedString("Optimizer", comment: ""), icon: "bolt.fill", isSelected: currentTab == .optimizer) {
                        currentTab = .optimizer
                    }
                    
                    TabButton(title: NSLocalizedString("Statistics", comment: ""), icon: "chart.bar.fill", isSelected: currentTab == .statistics) {
                        currentTab = .statistics
                    }
                    
                    TabButton(title: NSLocalizedString("Settings", comment: ""), icon: "gearshape.fill", isSelected: currentTab == .settings) {
                        currentTab = .settings
                    }
                }
                
                Spacer()
                
                // Right: Actions
                HStack(spacing: 12) {
                    // Progress Indicator (if processing)
                    if sessionStore.isProcessing {
                        ProgressView().controlSize(.small)
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                    }
                    
                    // Theme Toggle
                    Button(action: toggleAppearanceMode) {
                        Image(systemName: themeIconName)
                            .font(.system(size: 14))
                            .foregroundColor(Color.proTextMuted)
                    }
                    .buttonStyle(.plain)
                    .buttonStyle(.plain)
                    .help(NSLocalizedString("Toggle Theme", comment: ""))
                    
                    if !sessionStore.isProcessing && sessionStore.processedFiles.contains(where: { $0.status == .pending }) {
                        Button(action: {
                            Task { await sessionStore.startPendingCompression() }
                        }) {
                            Text(NSLocalizedString("Start", comment: ""))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.accentColor)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .transition(.scale)
                    }
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44) // Slightly taller for better touch targets
            .background(Color.proToolbar)
            .border(width: 1, edges: [.bottom], color: Color.proBorder)
            
            ZStack {
                // Main Background
                Color.proBg.ignoresSafeArea()
                
                switch currentTab {
                case .optimizer:
                    VStack(spacing: 0) {
                        if sessionStore.processedFiles.isEmpty {
                            // Drop Zone
                            if sessionStore.isProcessing {
                                ProcessingView(stats: sessionStore.stats, isProcessing: sessionStore.isProcessing, currentFileName: sessionStore.currentFileName)
                            } else {
                                DropZoneView(isTargeted: isTargeted)
                            }
                        } else {
                            // Results List
                            ResultsTableView(files: sessionStore.processedFiles) {
                                sessionStore.clearSession()
                            }
                        }
                    }
                case .statistics:
                     StatisticsView(settingsStore: settingsStore, sessionStore: sessionStore)
                case .settings:
                    SimpleSettingsView(
                        preset: $settingsStore.preset,
                        saveMode: $settingsStore.saveMode,
                        preserveMetadata: $settingsStore.preserveMetadata,
                        convertToSRGB: $settingsStore.convertToSRGB,
                        enableGifsicle: $settingsStore.enableGifsicle,
                        appearanceMode: $settingsStore.appearanceMode,
                        showDockIcon: $settingsStore.showDockIcon,
                        showMenuBarIcon: $settingsStore.showMenuBarIcon,
                        customJpegQuality: $settingsStore.customJpegQuality,
                        customPngLevel: $settingsStore.customPngLevel,
                        customAvifQuality: $settingsStore.customAvifQuality,
                        customAvifSpeed: $settingsStore.customAvifSpeed,
                        customWebPQuality: $settingsStore.customWebPQuality,
                        customWebPMethod: $settingsStore.customWebPMethod,
                        enableSvgcleaner: $settingsStore.enableSvgcleaner
                    )
                }
                
                ConfettiView(counter: confettiCounter)
            }
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
        if !processing && sessionStore.stats.totalInBatch > 0 && sessionStore.stats.failedFiles == 0 {
            // Success! Trigger confetti
            confettiCounter += 1
        }
    }

    // MARK: - Logic & Actions

    private func cancelProcessing() {
        NotificationCenter.default.post(name: .cancelProcessing, object: nil)
    }

    private func setupApp() {
        AppUIManager.shared.lockMainWindowSize(width: 600, height: 450)
        AppUIManager.shared.setupWindowPositionAutosave()
        
        // Ensure initial appearance is applied
        AppUIManager.shared.applyAppearance(settingsStore.appearanceMode)

        // Bind global shortcuts via store
        sessionStore.bindEvents()
    }
    
    // Legacy loadPreferences removed as SettingsStore handles persistence via @AppStorage
    // Legacy save handlers removed as SettingsStore handles persistence

    // handleAppearanceChange is removed as logic is moved to SettingsStore setter
    
    private func toggleAppearanceMode() {
        withAnimation {
            switch settingsStore.appearanceMode {
            case .auto: settingsStore.appearanceMode = .dark
            case .dark: settingsStore.appearanceMode = .light
            case .light: settingsStore.appearanceMode = .auto
            }
        }
    }

    private var themeIconName: String {
        switch settingsStore.appearanceMode {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .auto: return "circle.lefthalf.filled"
        }
    }
}

enum AppTab {
    case optimizer
    case statistics
    case settings
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.proBtnActive : Color.clear)
            .foregroundColor(isSelected ? Color.proTextMain : Color.proTextMuted)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subviews

struct DropZoneView: View {
    let isTargeted: Bool

    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "cloud")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(Color.proTextMuted)
            
            VStack(spacing: 5) {
                Text(NSLocalizedString("Drag files here to start batch", comment: ""))
                    .font(.system(size: 13))
                    .foregroundColor(Color.proTextMain)
                Text(NSLocalizedString("Supports nested folders", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(Color.proTextMuted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isTargeted ? Color.accentColor : Color.proBorder, style: StrokeStyle(lineWidth: 2, dash: [4]))
        )
        .padding(20)
    }
}

// MARK: - Processing View
struct ProcessingView: View {
    let stats: SessionStats
    let isProcessing: Bool
    let currentFileName: String
    @State private var isRotating: Bool = false
    @State private var isPulsing: Bool = false

    var body: some View {
        VStack(spacing: 30) {
            // Icon
            ZStack {
                // Background Track (Subtle)
                Circle()
                    .stroke(Color.proTextMuted.opacity(0.1), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                if isProcessing {
                    // 1. Outer Ripple (Expands and fades)
                    Circle()
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isPulsing ? 1.3 : 0.9)
                        .opacity(isPulsing ? 0.0 : 0.5)
                    
                    // 2. Scanner Ring (Rotating Gradient)
                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.clear, Color.accentColor]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
                    
                    // 3. Inner Core (Breathing)
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                        .scaleEffect(isPulsing ? 1.0 : 0.7)
                        
                    // Animation Triggers
                    Text("") // Hidden trigger
                        .onAppear {
                            // Rotation: Continuous linear
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                isRotating = true
                            }
                            // Pulse: Rhythmic breathing
                            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                isPulsing = true
                            }
                        }
                } else {
                     Image(systemName: statusIcon)
                        .font(.system(size: 30))
                        .foregroundColor(statusColor)
                }
            }

            VStack(spacing: 8) {
                Text(NSLocalizedString(statusTitle, comment: ""))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color.proTextMain) // Adaptive

                if isProcessing && !currentFileName.isEmpty {
                    Text(currentFileName)
                        .font(.system(size: 12))
                        .foregroundColor(Color.proTextMuted) // Adaptive
                        .truncationMode(.middle)
                        .frame(maxWidth: 300)
                }
            }

            // Progress Bar
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.proTextMuted.opacity(0.1)) // Adaptive
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: geo.size.width * CGFloat(progress), height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 40)
                
                HStack {
                    Text("\(Int(progress * 100))%")
                    Spacer()
                    Text("\(stats.processedFiles) / \(stats.totalInBatch)")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(Color.proTextMuted) // Adaptive
                .padding(.horizontal, 40)
            }


            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatPip(title: NSLocalizedString("SAVED", comment: ""), value: ByteCountFormatter.string(fromByteCount: stats.savedBytes, countStyle: .file))
                StatPip(title: NSLocalizedString("SUCCESS", comment: ""), value: "\(stats.successfulFiles)")
                StatPip(title: NSLocalizedString("SKIPPED", comment: ""), value: "\(stats.skippedFiles)")
                StatPip(title: NSLocalizedString("ERRORS", comment: ""), value: "\(stats.failedFiles)", isError: stats.failedFiles > 0)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.proBg)
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
        if isProcessing { return "gearshape.fill" }
        if stats.failedFiles > 0 { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    var statusTitle: String {
        if isProcessing { return "Optimizing..." }
        if stats.failedFiles > 0 { return "Done with Errors" }
        return "Complete!"
    }
}

struct StatPip: View {
    let title: String
    let value: String
    var isError: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(Color.proTextMuted)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isError ? .red : Color.proTextMain)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.proBorder.opacity(0.4)) // Visible in both light (greyish) and dark modes
        .cornerRadius(4)
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

// MARK: - Drop Delegate
struct AppDropDelegate: DropDelegate {
    let sessionStore: SessionStore
    let settingsStore: SettingsStore
    @Binding var isTargeted: Bool
    @Binding var currentTab: AppTab
    
    func dropEntered(info: DropInfo) {
        isTargeted = true
    }
    
    func dropExited(info: DropInfo) {
        isTargeted = false
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        return true 
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.item, .fileURL, .url, .text])
        
        Task { @MainActor in
            // Immediately switch to Optimizer tab so user sees progress
            currentTab = .optimizer
            
            sessionStore.settingsStore = settingsStore
            await sessionStore.handleDrop(providers: providers)
        }
        
        isTargeted = false
        return true
    }
}
