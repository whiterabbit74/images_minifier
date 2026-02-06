import SwiftUI
import PicsMinifierCore

@MainActor
class SettingsStore: ObservableObject {
    // UI Settings
    @AppStorage("ui.appearanceMode") var appearanceModeRaw: String = AppearanceMode.auto.rawValue
    @AppStorage("ui.showDockIcon") var showDockIcon: Bool = true
    @AppStorage("ui.showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("ui.launchAtLogin") var launchAtLogin: Bool = false
    @AppStorage("ui.notifyOnCompletion") var notifyOnCompletion: Bool = true
    @AppStorage("ui.language") var languageRaw: String = AppLanguage.auto.rawValue
    
    // Compression Settings
    @AppStorage("settings.preset") var presetRaw: String = CompressionPreset.balanced.rawValue
    @AppStorage("settings.saveMode") var saveModeRaw: String = SaveMode.suffix.rawValue
    @AppStorage("settings.preserveMetadata") var preserveMetadata: Bool = true
    @AppStorage("settings.convertToSRGB") var convertToSRGB: Bool = false
    @AppStorage("settings.enableGifsicle") var enableGifsicle: Bool = true
    @AppStorage("settings.enableGifLossy") var enableGifLossy: Bool = false
    @AppStorage("settings.compressImmediately") var compressImmediately: Bool = true
    @AppStorage("settings.enableSvgcleaner") var enableSvgcleaner: Bool = true
    @AppStorage("settings.svgPrecision") private var _svgPrecision: Int = 3
    @AppStorage("settings.svgMultipass") private var _svgMultipass: Bool = false
    
    // Statistics
    @AppStorage("stats.disableStatistics") var disableStatistics: Bool = false
    @AppStorage("stats.lifetimeCount") var lifetimeCompressedCount: Int = 0
    @AppStorage("stats.lifetimeOriginal") var lifetimeOriginalBytes: Int = 0
    // Storing as Int (max 2PB approx, sufficient)
    @AppStorage("stats.lifetimeSaved") var lifetimeSavedBytes: Int = 0
    @AppStorage("stats.formatSavings") var formatSavingsData: Data = Data()
    
    // Custom Settings
    // Private Storage for Logic
    @AppStorage("settings.customJpegQuality") private var _customJpegQuality: Double = 0.84
    @AppStorage("settings.customPngLevel") private var _customPngLevel: Int = 4
    @AppStorage("settings.advanced.customAvifQuality") private var _customAvifQuality: Int = 28
    @AppStorage("settings.advanced.customAvifSpeed") private var _customAvifSpeed: Int = 3
    @AppStorage("settings.customWebPQuality") private var _customWebPQuality: Int = 88
    @AppStorage("settings.customWebPMethod") private var _customWebPMethod: Int = 5
    
    // User Presets
    @AppStorage("settings.userPresets") var userPresetsData: Data = Data()
    @AppStorage("settings.activeUserPresetId") var activeUserPresetIdString: String = ""
    
    var activeUserPresetId: UUID? {
        get { UUID(uuidString: activeUserPresetIdString) }
        set { activeUserPresetIdString = newValue?.uuidString ?? "" }
    }
    
    var userPresets: [UserPreset] {
        get {
            guard !userPresetsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([UserPreset].self, from: userPresetsData)) ?? []
        }
        set {
            userPresetsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
    
    func saveCurrentAsPreset(name: String) {
        print("Saving preset: \(name)")
        let newPreset = UserPreset(name: name, settings: self.settings)
        var current = userPresets
        current.append(newPreset)
        userPresets = current
        
        // Force UI update and switch to custom
        preset = .custom
        activeUserPresetId = newPreset.id
        objectWillChange.send() 
    }
    
    func deletePreset(id: UUID) {
        var current = userPresets
        current.removeAll { $0.id == id }
        userPresets = current
    }
    
    func applyUserPreset(_ userPreset: UserPreset) {
        _customJpegQuality = userPreset.customJpegQuality
        _customPngLevel = userPreset.customPngLevel
        _customAvifQuality = userPreset.customAvifQuality
        _customAvifSpeed = userPreset.customAvifSpeed
        _customAvifSpeed = userPreset.customAvifSpeed
        _customWebPQuality = userPreset.customWebPQuality
        _customWebPMethod = userPreset.customWebPMethod
        enableSvgcleaner = userPreset.enableSvgcleaner
        _svgPrecision = userPreset.svgPrecision
        _svgMultipass = userPreset.svgMultipass
        enableGifsicle = userPreset.enableGifsicle
        preserveMetadata = userPreset.preserveMetadata
        convertToSRGB = userPreset.convertToSRGB
        
        // Set mode to custom effectively
        preset = .custom
        activeUserPresetId = userPreset.id
        objectWillChange.send()
    }
    
    // Resizing
    @AppStorage("settings.resize.enabled") var resizeEnabled: Bool = false
    @AppStorage("settings.resize.value") var resizeValue: Int = 1920
    @AppStorage("settings.resize.condition") var resizeConditionRaw: String = ResizeCondition.fit.rawValue
    
    var resizeCondition: ResizeCondition {
        get { ResizeCondition(rawValue: resizeConditionRaw) ?? .fit }
        set { resizeConditionRaw = newValue.rawValue }
    }
    
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

    var customWebPQuality: Int {
        get { _customWebPQuality }
        set {
            let clamped = max(1, min(100, newValue))
            if _customWebPQuality != clamped {
                _customWebPQuality = clamped
                switchToCustomIfNeeded()
            }
        }
    }

    var customWebPMethod: Int {
        get { _customWebPMethod }
        set {
            let clamped = max(0, min(6, newValue))
            if _customWebPMethod != clamped {
                _customWebPMethod = clamped
                switchToCustomIfNeeded()
            }
        }
    }

    var svgPrecision: Int {
        get { _svgPrecision }
        set {
            let clamped = max(0, min(10, newValue))
            if _svgPrecision != clamped {
                _svgPrecision = clamped
                switchToCustomIfNeeded()
            }
        }
    }

    var svgMultipass: Bool {
        get { _svgMultipass }
        set {
            if _svgMultipass != newValue {
                _svgMultipass = newValue
                switchToCustomIfNeeded()
            }
        }
    }
    
    private func switchToCustomIfNeeded() {
        if preset != .custom {
            preset = .custom
        }
        // If we were on a named preset, we are now modified, so drop the name linkage
        // (Or we could keep it and add "Modified" in UI, but simple for now)
        if activeUserPresetId != nil {
            activeUserPresetId = nil
        }
    }
    
    // Accessors for Enums
    // We use a private backing store for the actual persistence
    @AppStorage("ui.appearanceMode") private var internalAppearanceModeRaw: String = AppearanceMode.auto.rawValue
    
    // Public proxy that triggers the immediate UI update
    var appearanceMode: AppearanceMode {
        get { AppearanceMode(rawValue: internalAppearanceModeRaw) ?? .auto }
        set {
            // 1. Trigger the global appearance update IMMEDIATELY
            AppUIManager.shared.applyAppearance(newValue)
            
            // 2. Persist the value (which might trigger SwiftUI updates, but the global state is now correct)
            internalAppearanceModeRaw = newValue.rawValue
        }
    }
    
    var language: AppLanguage {
        get { AppLanguage(rawValue: languageRaw) ?? .auto }
        set {
            languageRaw = newValue.rawValue
            LanguageManager.shared.applyLanguage(newValue)
            // Note: Most apps require restart for AppleLanguages to take full effect
            // but we apply it to defaults correctly here.
        }
    }
    
    var preset: CompressionPreset {
        get { CompressionPreset(rawValue: presetRaw) ?? .balanced }
        set { 
            presetRaw = newValue.rawValue
            // Only apply values if NOT custom. If keeping custom, we keep current values.
            if newValue != .custom {
                applyPresetValues(newValue)
                activeUserPresetId = nil // Clear user preset linkage
            }
        }
    }
    
    // ...

    private func applyPresetValues(_ preset: CompressionPreset) {
        // Prevent feedback loop: Direct access to underlying storage
        switch preset {
        case .quality:
            _customJpegQuality = 0.92
            _customPngLevel = 4
            _customAvifQuality = 45
            _customAvifSpeed = 2
            _customWebPQuality = 95
            _customWebPMethod = 6
            _svgPrecision = 4
            _svgMultipass = false
        case .balanced:
            _customJpegQuality = 0.84
            _customPngLevel = 4
            _customAvifQuality = 28
            _customAvifSpeed = 3
            _customWebPQuality = 88
            _customWebPMethod = 5
            _svgPrecision = 3
            _svgMultipass = false
        case .saving:
            _customJpegQuality = 0.72
            _customPngLevel = 6 
            _customAvifQuality = 35
            _customAvifSpeed = 4
            _customWebPQuality = 82
            _customWebPMethod = 5
            _svgPrecision = 2
            _svgMultipass = true
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
        enableSvgcleaner = true
        svgPrecision = 3
        svgMultipass = false
        appearanceMode = .auto
        language = .auto
        showDockIcon = true
        showMenuBarIcon = true
        resizeEnabled = false
        resizeValue = 1920
        resizeValue = 1920
        resizeCondition = .fit
        compressImmediately = true
        
        // These are reset by setting preset to .balanced above
    }
    
    var settings: AppSettings {
        var s = AppSettings()
        s.preset = preset
        s.saveMode = saveMode
        s.preserveMetadata = preserveMetadata
        s.convertToSRGB = convertToSRGB
        s.enableGifsicle = enableGifsicle
        s.enableGifLossy = enableGifLossy
        s.enableSvgcleaner = enableSvgcleaner
        s.svgPrecision = svgPrecision
        s.svgMultipass = svgMultipass
        
        s.customJpegQuality = customJpegQuality
        s.customPngLevel = customPngLevel
        s.customAvifQuality = customAvifQuality
        s.customAvifSpeed = customAvifSpeed
        s.customWebPQuality = customWebPQuality
        s.customWebPMethod = customWebPMethod
        
        s.resizeEnabled = resizeEnabled
        s.resizeValue = resizeValue
        s.resizeValue = resizeValue
        s.resizeCondition = resizeCondition
        s.compressImmediately = compressImmediately
        
        return s
    }

    var launchAtLoginProxy: Bool {
        get { launchAtLogin }
        set {
            launchAtLogin = newValue
            // TODO: Call AppUIManager to handle actual logic
             AppUIManager.shared.setLaunchAtLogin(newValue)
        }
    }

    // Statistics Helpers
    func updateFormatSavings(extension ext: String, savedBytes: Int) {
        guard !disableStatistics else { return }
        
        var current = formatSavings
        let key = ext.lowercased()
        current[key] = (current[key] ?? 0) + savedBytes
        formatSavings = current
    }

    var formatSavings: [String: Int] {
        get {
            guard !formatSavingsData.isEmpty else { return [:] }
            return (try? JSONDecoder().decode([String: Int].self, from: formatSavingsData)) ?? [:]
        }
        set {
            formatSavingsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }
}
