import SwiftUI
import PicsMinifierCore

@MainActor
class SettingsStore: ObservableObject {
    // UI Settings
    @AppStorage("ui.appearanceMode") var appearanceModeRaw: String = AppearanceMode.auto.rawValue
    @AppStorage("ui.showDockIcon") var showDockIcon: Bool = true
    @AppStorage("ui.showMenuBarIcon") var showMenuBarIcon: Bool = true
    
    // Compression Settings
    @AppStorage("settings.preset") var presetRaw: String = CompressionPreset.balanced.rawValue
    @AppStorage("settings.saveMode") var saveModeRaw: String = SaveMode.suffix.rawValue
    @AppStorage("settings.preserveMetadata") var preserveMetadata: Bool = true
    @AppStorage("settings.convertToSRGB") var convertToSRGB: Bool = false
    @AppStorage("settings.enableGifsicle") var enableGifsicle: Bool = true
    
    // Custom Settings
    // Private Storage for Logic
    @AppStorage("settings.customJpegQuality") private var _customJpegQuality: Double = 0.82
    @AppStorage("settings.customPngLevel") private var _customPngLevel: Int = 3
    @AppStorage("settings.customAvifQuality") private var _customAvifQuality: Int = 28
    @AppStorage("settings.customAvifSpeed") private var _customAvifSpeed: Int = 4
    
    // Public Accessors with Auto-Switch Logic
    var customJpegQuality: Double {
        get { _customJpegQuality }
        set {
            if _customJpegQuality != newValue {
                _customJpegQuality = newValue
                switchToCustomIfNeeded()
            }
        }
    }
    
    var customPngLevel: Int {
        get { _customPngLevel }
        set {
            if _customPngLevel != newValue {
                _customPngLevel = newValue
                switchToCustomIfNeeded()
            }
        }
    }
    
    var customAvifQuality: Int {
        get { _customAvifQuality }
        set {
            if _customAvifQuality != newValue {
                _customAvifQuality = newValue
                switchToCustomIfNeeded()
            }
        }
    }
    
    var customAvifSpeed: Int {
        get { _customAvifSpeed }
        set {
            if _customAvifSpeed != newValue {
                _customAvifSpeed = newValue
                switchToCustomIfNeeded()
            }
        }
    }
    
    private func switchToCustomIfNeeded() {
        if preset != .custom {
            preset = .custom
        }
    }
    
    // Accessors for Enums
    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: appearanceModeRaw) ?? .auto }
        set { appearanceModeRaw = newValue.rawValue }
    }
    
    var preset: CompressionPreset {
        get { CompressionPreset(rawValue: presetRaw) ?? .balanced }
        set { 
            presetRaw = newValue.rawValue
            // Only apply values if NOT custom. If keeping custom, we keep current values.
            if newValue != .custom {
                applyPresetValues(newValue)
            }
        }
    }
    
    // ...

    private func applyPresetValues(_ preset: CompressionPreset) {
        // Prevent feedback loop: Direct access to underlying storage
        switch preset {
        case .quality:
            _customJpegQuality = 0.90
            _customPngLevel = 2 
            _customAvifQuality = 45
            _customAvifSpeed = 3
        case .balanced:
            _customJpegQuality = 0.82
            _customPngLevel = 3
            _customAvifQuality = 28
            _customAvifSpeed = 4
        case .saving:
            _customJpegQuality = 0.70
            _customPngLevel = 6 
            _customAvifQuality = 20
            _customAvifSpeed = 5
        default:
            break
        }
    }
    
    var saveMode: SaveMode {
        get { SaveMode(rawValue: saveModeRaw) ?? .suffix }
        set { saveModeRaw = newValue.rawValue }
    }
    
    func resetToDefaults() {
        preset = .balanced
        saveMode = .suffix
        preserveMetadata = true
        convertToSRGB = false
        enableGifsicle = true
        appearanceMode = .auto
        showDockIcon = true
        showMenuBarIcon = true
        
        // These are reset by setting preset to .balanced above
    }
}
