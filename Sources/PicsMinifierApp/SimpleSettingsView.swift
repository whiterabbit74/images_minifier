import SwiftUI
import PicsMinifierCore

struct SimpleSettingsView: View {
    @Bindable var store: SettingsStore
    
    // Computed interface mode
    private var interfaceMode: InterfaceMode {
        get {
            if store.showDockIcon && store.showMenuBarIcon { return .both }
            if store.showDockIcon { return .dock }
            return .menuBar
        }
        set {
            switch newValue {
            case .dock:
                store.showDockIcon = true
                store.showMenuBarIcon = false
            case .menuBar:
                store.showDockIcon = false
                store.showMenuBarIcon = true
            case .both:
                store.showDockIcon = true
                store.showMenuBarIcon = true
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
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("Settings", comment: ""))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.proTextMain)
                
                Text(NSLocalizedString("Configure app behavior and interface", comment: ""))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.proTextMuted)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glossyMaterial(.headerView)
            .border(width: 1, edges: [.bottom], color: Color.proBorder)
            
            ScrollView {
                Form {
                    // MARK: - General
                    Section {
                        LabeledContent {
                            Toggle("", isOn: $store.launchAtLoginProxy)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .accessibilityLabel(NSLocalizedString("Launch at Login", comment: ""))
                        } label: {
                            SettingsLabel(title: NSLocalizedString("Launch at Login", comment: ""), icon: "desktopcomputer")
                        }
                        
                        LabeledContent {
                            Toggle("", isOn: $store.notifyOnCompletion)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .accessibilityLabel(NSLocalizedString("Notify on Completion", comment: ""))
                        } label: {
                            SettingsLabel(title: NSLocalizedString("Notify on Completion", comment: ""), icon: "bell.fill")
                        }
                        
                        LabeledContent {
                            Toggle("", isOn: $store.playSoundOnCompletion)
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .accessibilityLabel(NSLocalizedString("Sound on Completion", comment: ""))
                        } label: {
                            SettingsLabel(title: NSLocalizedString("Sound on Completion", comment: ""), icon: "speaker.wave.2.fill")
                        }
                    } header: {
                        Text(NSLocalizedString("WORKFLOW", comment: ""))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.proTextMuted)
                            .padding(.top, 16)
                    }

                    // MARK: - Interface
                    Section {
                        LabeledContent {
                            Picker("", selection: $store.appearanceMode) {
                                Text(NSLocalizedString("Auto", comment: "")).tag(AppearanceMode.auto)
                                Text(NSLocalizedString("Dark", comment: "")).tag(AppearanceMode.dark)
                                Text(NSLocalizedString("Light", comment: "")).tag(AppearanceMode.light)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .accessibilityLabel(NSLocalizedString("Appearance Mode", comment: ""))
                        } label: {
                            SettingsLabel(title: NSLocalizedString("Theme", comment: ""), icon: "paintpalette.fill")
                        }
                        
                        LabeledContent {
                            Picker("", selection: Binding(
                                get: { interfaceMode },
                                set: { newValue in
                                    switch newValue {
                                    case .dock:
                                        store.showDockIcon = true
                                        store.showMenuBarIcon = false
                                    case .menuBar:
                                        store.showDockIcon = false
                                        store.showMenuBarIcon = true
                                    case .both:
                                        store.showDockIcon = true
                                        store.showMenuBarIcon = true
                                    }
                                }
                            )) {
                                ForEach(InterfaceMode.allCases) { mode in
                                    Text(mode.localizedName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                            .accessibilityLabel(NSLocalizedString("Interface Mode", comment: ""))
                        } label: {
                            SettingsLabel(title: NSLocalizedString("App Visibility", comment: ""), icon: "macwindow")
                        }
                        
                        LabeledContent {
                            Menu {
                                ForEach(AppLanguage.allCases, id: \.self) { lang in
                                    Button(LanguageManager.shared.getCurrentLanguageDisplayName(for: lang)) {
                                        store.language = lang
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(store.language.displayName)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 8))
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(Color.proTextMain)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.proBtnActive)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            .menuStyle(.borderlessButton)
                            .accessibilityLabel(NSLocalizedString("Application Language", comment: ""))
                        } label: {
                            SettingsLabel(title: NSLocalizedString("Language", comment: ""), icon: "globe")
                        }
                    } header: {
                        Text(NSLocalizedString("INTERFACE", comment: ""))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.proTextMuted)
                            .padding(.top, 24)
                    }
                }
                .formStyle(.grouped)
                .padding(.horizontal, 8)
            }
            
            // Footer
            HStack {
                Text("PicsMinifier Pro v.2.6")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.proTextMuted)
                
                Spacer()
                
                Button(action: { store.resetToDefaults() }) {
                    Text(NSLocalizedString("Reset to Defaults", comment: ""))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityHint(NSLocalizedString("Restores all settings to their original values", comment: ""))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .glossyMaterial(.headerView)
            .border(width: 1, edges: [.top], color: Color.proBorder)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.proBg)
    }
}

// MARK: - Components

struct SettingsLabel: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.proAccent.opacity(0.12))
                    .frame(width: 26, height: 26)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.proAccent)
            }
            
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.proTextMain)
        }
    }
}
