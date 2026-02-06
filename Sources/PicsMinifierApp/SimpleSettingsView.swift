import SwiftUI
import PicsMinifierCore

struct SimpleSettingsView: View {
    @Binding var preset: CompressionPreset
    @Binding var saveMode: SaveMode
    @Binding var preserveMetadata: Bool
    @Binding var convertToSRGB: Bool
    @Binding var enableGifsicle: Bool
    @Binding var appearanceMode: AppearanceMode
    @Binding var showDockIcon: Bool
    @Binding var showMenuBarIcon: Bool
    
    // Custom Settings (Unused in this view but passed for compatibility)
    @Binding var customJpegQuality: Double
    @Binding var customPngLevel: Int
    @Binding var customAvifQuality: Int
    @Binding var customAvifSpeed: Int
    @Binding var customWebPQuality: Int
    @Binding var customWebPMethod: Int
    @Binding var enableSvgcleaner: Bool
    
    @ObservedObject var store: SettingsStore // Access new properties
    
    // Init adapter to grab store reference
    init(
        preset: Binding<CompressionPreset>,
        saveMode: Binding<SaveMode>,
        preserveMetadata: Binding<Bool>,
        convertToSRGB: Binding<Bool>,
        enableGifsicle: Binding<Bool>,
        appearanceMode: Binding<AppearanceMode>,
        showDockIcon: Binding<Bool>,
        showMenuBarIcon: Binding<Bool>,
        customJpegQuality: Binding<Double>,
        customPngLevel: Binding<Int>,
        customAvifQuality: Binding<Int>,
        customAvifSpeed: Binding<Int>,
        customWebPQuality: Binding<Int>,
        customWebPMethod: Binding<Int>,
        enableSvgcleaner: Binding<Bool>
    ) {
        _preset = preset
        _saveMode = saveMode
        _preserveMetadata = preserveMetadata
        _convertToSRGB = convertToSRGB
        _enableGifsicle = enableGifsicle
        _appearanceMode = appearanceMode
        _showDockIcon = showDockIcon
        _showMenuBarIcon = showMenuBarIcon
        _customJpegQuality = customJpegQuality
        _customPngLevel = customPngLevel
        _customAvifQuality = customAvifQuality
        _customAvifSpeed = customAvifSpeed
        _customWebPQuality = customWebPQuality
        _customWebPMethod = customWebPMethod
        _enableSvgcleaner = enableSvgcleaner
        
        // Create a local instance to access AppStorage wrappers for new keys
        self.store = SettingsStore() 
    }
    
    // Computed interface mode
    private var interfaceMode: InterfaceMode {
        get {
            if showDockIcon && showMenuBarIcon { return .both }
            if showDockIcon { return .dock }
            return .menuBar // Default fallback
        }
        set {
            switch newValue {
            case .dock:
                showDockIcon = true
                showMenuBarIcon = false
            case .menuBar:
                showDockIcon = false
                showMenuBarIcon = true
            case .both:
                showDockIcon = true
                showMenuBarIcon = true
            }
        }
    }
    
    enum InterfaceMode: String, CaseIterable, Identifiable {
        case dock = "Dock"
        case menuBar = "Menu Bar"
        case both = "Both"

        var localizedName: String {
            NSLocalizedString(rawValue, comment: "")
        }
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(NSLocalizedString("Settings", comment: ""))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(16)
            .background(Color(hex: "1e1e1e"))
            .border(width: 1, edges: [.bottom], color: Color(hex: "333333"))
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // General Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: NSLocalizedString("GENERAL", comment: ""), icon: "gear")
                        
                        ProToggle(isOn: $store.launchAtLoginProxy, title: NSLocalizedString("Launch at Login", comment: ""), icon: "desktopcomputer")
                        ProToggle(isOn: $store.notifyOnCompletion, title: NSLocalizedString("Notify on Completion", comment: ""), icon: "bell.badge")
                    }
                    
                    Divider().background(Color(hex: "333333"))
                    
                    // Interface Section
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader(title: NSLocalizedString("INTERFACE", comment: ""), icon: "macwindow")
                        
                        // Theme
                        HStack {
                            Label(NSLocalizedString("Theme", comment: ""), systemImage: "paintpalette")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "dddddd"))
                            Spacer()
                            Picker("", selection: $appearanceMode) {
                                Text(NSLocalizedString("System", comment: "")).tag(AppearanceMode.auto)
                                Text(NSLocalizedString("Dark", comment: "")).tag(AppearanceMode.dark)
                                Text(NSLocalizedString("Light", comment: "")).tag(AppearanceMode.light)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }
                        .padding(12)
                        .background(Color(hex: "252525"))
                        .cornerRadius(8)
                        
                        // Icons Visibility (Horizontal Picker)
                        HStack {
                            Label(NSLocalizedString("App Icon", comment: ""), systemImage: "app.dashed")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "dddddd"))
                            Spacer()
                            Picker("", selection: Binding(
                                get: { interfaceMode },
                                set: { newValue in
                                    // Manually expand the setter logic here to avoid 'self is immutable' on property assignment
                                    switch newValue {
                                    case .dock:
                                        showDockIcon = true
                                        showMenuBarIcon = false
                                    case .menuBar:
                                        showDockIcon = false
                                        showMenuBarIcon = true
                                    case .both:
                                        showDockIcon = true
                                        showMenuBarIcon = true
                                    }
                                }
                            )) {
                                ForEach(InterfaceMode.allCases) { mode in
                                    Text(mode.localizedName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 220)
                        }
                        .padding(12)
                        .background(Color(hex: "252525"))
                        .cornerRadius(8)

                        // Language
                        HStack {
                            Label(NSLocalizedString("Language", comment: ""), systemImage: "globe")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "dddddd"))
                            Spacer()
                            Menu {
                                ForEach(AppLanguage.allCases, id: \.self) { lang in
                                    Button(action: {
                                        store.language = lang
                                    }) {
                                        Text(LanguageManager.shared.getCurrentLanguageDisplayName(for: lang))
                                    }
                                }
                            } label: {
                                Text(store.language.displayName)
                            }
                            .frame(width: 220, alignment: .trailing)
                        }
                        .padding(12)
                        .background(Color(hex: "252525"))
                        .cornerRadius(8)
                    }
                     
                }
                .padding(20)
            }
            
            // Footer
            HStack {
                Spacer()
                Button(NSLocalizedString("Reset All", comment: "")) {
                    store.resetToDefaults()
                }
                .font(.caption)
                .foregroundColor(.gray)
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(hex: "1e1e1e"))
            .border(width: 1, edges: [.top], color: Color(hex: "333333"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "1a1a1a"))
    }
}

// MARK: - Components

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.gray)
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
        }
        .padding(.bottom, 4)
    }
}

struct ProToggle: View {
    @Binding var isOn: Bool
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "dddddd"))
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        }
        .padding(12)
        .background(Color(hex: "252525"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "333333"), lineWidth: 1)
        )
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
