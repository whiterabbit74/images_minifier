import SwiftUI
import AppKit
import PicsMinifierCore
import UniformTypeIdentifiers

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var sessionStore = SessionStore()
    
    @State private var systemIsDark: Bool = false
    @State private var isTargeted: Bool = false
    @State private var confirmOverwrite: Bool = false
    @State var showingSettings: Bool = false // Keeping for now, will replace with Sidebar later
    @State var progressObserverTokens: [NSObjectProtocol] = []
    @State private var confettiCounter: Int = 0 // Trigger for confetti

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView(settingsStore: settingsStore)
            
            // Divider
            Divider()
                .background(Color.proBorder)
            
            // Main Content Area
            VStack(spacing: 0) {
                // Top Toolbar
                HStack(spacing: 12) {
                    Text("Batch Optimizer")
                        .font(.system(size: 13))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.proBtnActive)
                        .foregroundColor(Color.proTextMain) // Adaptive text
                        .cornerRadius(4)
                    
                    Text("History")
                        .font(.system(size: 13))
                        .foregroundColor(Color.proTextMuted)
                    
                    Spacer()
                    
                    // Small status indicator
                    if sessionStore.isProcessing {
                        ProgressView().controlSize(.small)
                            .scaleEffect(0.8)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 35)
                .background(Color.proToolbar)
                .border(width: 1, edges: [.bottom], color: Color.proBorder)
                
                ZStack {
                    // Main Background
                    Color.proBg.ignoresSafeArea()
                    
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
                            ResultsTableView(files: sessionStore.processedFiles)
                        }
                    }
                    
                    ConfettiView(counter: confettiCounter)
                }
            }
        }
        .contentShape(Rectangle())
        .onDrop(of: [.item, .fileURL, .url, .text], delegate: AppDropDelegate(sessionStore: sessionStore, settingsStore: settingsStore, isTargeted: $isTargeted))
        .frame(minWidth: 800, minHeight: 600)
        .modifier(AppearanceModifier(mode: settingsStore.appearanceMode))
        .onAppear(perform: setupApp)
        .onChange(of: settingsStore.appearanceMode, perform: handleAppearanceChange)
        .onChange(of: settingsStore.showDockIcon, perform: updateDockIcon)
        .onChange(of: settingsStore.showMenuBarIcon, perform: updateMenuBarIcon)
        .onChange(of: sessionStore.isProcessing) { processing in
            if !processing && sessionStore.stats.totalInBatch > 0 && sessionStore.stats.failedFiles == 0 {
                confettiCounter += 1
            }
        }
    }

    // The mainLayout @ViewBuilder is removed as its content is now directly in body
    // The contentStack @ViewBuilder is removed as its content is now directly in body
    // The mainContent @ViewBuilder is removed as its content is now directly in body
    // The headerView @ViewBuilder is removed as its content is now directly in body
    // The centerView @ViewBuilder is removed as its content is now directly in body
    // The footerView @ViewBuilder is removed as its content is now directly in body
    // The globalStatsView @ViewBuilder is removed as its content is now directly in body

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
        AppUIManager.shared.lockMainWindowSize(width: 800, height: 600)
        AppUIManager.shared.setupWindowPositionAutosave()
        updateSystemTheme()

        DistributedNotificationCenter.default.addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { _ in updateSystemTheme() }

        // Bind global shortcuts via store
        sessionStore.bindEvents()
    }
    
    // Legacy loadPreferences removed as SettingsStore handles persistence via @AppStorage
    // Legacy save handlers removed as SettingsStore handles persistence

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
            switch settingsStore.appearanceMode {
            case .auto: settingsStore.appearanceMode = .dark
            case .dark: settingsStore.appearanceMode = .light
            case .light: settingsStore.appearanceMode = .auto
            }
        }
    }

    private func updateSystemTheme() {
        let appearance = NSApp.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        if systemIsDark != isDark {
            systemIsDark = isDark
            if settingsStore.appearanceMode == .auto {
                DispatchQueue.main.async { NSApp.appearance = nil }
            }
        }
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
                Text("Drag files here to start batch")
                    .font(.system(size: 13))
                    .foregroundColor(Color.proTextMain)
                Text("Supports nested folders")
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

    var body: some View {
        VStack(spacing: 30) {
            // Icon
            ZStack {
                Circle()
                    .stroke(Color.proTextMuted.opacity(0.2), lineWidth: 4) // Adaptive
                    .frame(width: 80, height: 80)
                
                if isProcessing {
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
                        .onAppear {
                            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                isRotating = true
                            }
                        }
                } else {
                     Image(systemName: statusIcon)
                        .font(.system(size: 30))
                        .foregroundColor(statusColor)
                }
            }

            VStack(spacing: 8) {
                Text(statusTitle)
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
                StatPip(title: "SAVED", value: ByteCountFormatter.string(fromByteCount: stats.savedBytes, countStyle: .file))
                StatPip(title: "SUCCESS", value: "\(stats.successfulFiles)")
                StatPip(title: "SKIPPED", value: "\(stats.skippedFiles)")
                StatPip(title: "ERRORS", value: "\(stats.failedFiles)", isError: stats.failedFiles > 0)
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
    
    func dropEntered(info: DropInfo) {
        print("DEBUG: Drop entered window")
        isTargeted = true
    }
    
    func dropExited(info: DropInfo) {
        print("DEBUG: Drop exited window")
        isTargeted = false
    }
    
    func validateDrop(info: DropInfo) -> Bool {
        print("DEBUG: Validating drop with types: \(info.itemProviders(for: [.item]).count) providers")
        return true 
    }
    
    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.item, .fileURL, .url, .text])
        print("DEBUG: performing drop with \(providers.count) providers")
        
        Task {
            sessionStore.settingsStore = settingsStore
            await sessionStore.handleDrop(providers: providers)
        }
        
        isTargeted = false
        return true
    }
}
