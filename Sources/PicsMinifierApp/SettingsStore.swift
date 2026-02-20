import SwiftUI
import PicsMinifierCore
import Observation

@Observable
@MainActor
class SettingsStore {
    // MARK: - UI Settings Persistence
    
    private var appearanceModeRaw: String {
        get { UserDefaults.standard.string(forKey: "ui.appearanceMode") ?? AppearanceMode.auto.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "ui.appearanceMode") }
    }
    
    var showDockIcon: Bool {
        get {
            access(keyPath: \.showDockIcon)
            return UserDefaults.standard.object(forKey: "ui.showDockIcon") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showDockIcon) {
                UserDefaults.standard.set(newValue, forKey: "ui.showDockIcon")
            }
        }
    }
    
    var showMenuBarIcon: Bool {
        get {
            access(keyPath: \.showMenuBarIcon)
            return UserDefaults.standard.object(forKey: "ui.showMenuBarIcon") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.showMenuBarIcon) {
                UserDefaults.standard.set(newValue, forKey: "ui.showMenuBarIcon")
            }
        }
    }
    
    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: "ui.launchAtLogin") }
        set { UserDefaults.standard.set(newValue, forKey: "ui.launchAtLogin") }
    }
    
    var notifyOnCompletion: Bool {
        get {
            access(keyPath: \.notifyOnCompletion)
            return UserDefaults.standard.object(forKey: "ui.notifyOnCompletion") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.notifyOnCompletion) {
                UserDefaults.standard.set(newValue, forKey: "ui.notifyOnCompletion")
            }
        }
    }
    
    var playSoundOnCompletion: Bool {
        get {
            access(keyPath: \.playSoundOnCompletion)
            return UserDefaults.standard.object(forKey: "ui.playSoundOnCompletion") as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.playSoundOnCompletion) {
                UserDefaults.standard.set(newValue, forKey: "ui.playSoundOnCompletion")
            }
        }
    }
    
    var languageRaw: String {
        get { UserDefaults.standard.string(forKey: "ui.language") ?? AppLanguage.auto.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "ui.language") }
    }
    
    // MARK: - Compression Settings Persistence
    
    var presetRaw: String {
        get { UserDefaults.standard.string(forKey: "settings.preset") ?? CompressionPreset.balanced.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "settings.preset") }
    }
    
    var saveModeRaw: String {
        get { UserDefaults.standard.string(forKey: "settings.saveMode") ?? SaveMode.suffix.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "settings.saveMode") }
    }
    
    var preserveMetadata: Bool {
        get { UserDefaults.standard.object(forKey: "settings.preserveMetadata") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "settings.preserveMetadata") }
    }
    
    var convertToSRGB: Bool {
        get { UserDefaults.standard.bool(forKey: "settings.convertToSRGB") }
        set { UserDefaults.standard.set(newValue, forKey: "settings.convertToSRGB") }
    }
    
    var enableGifsicle: Bool {
        get { UserDefaults.standard.object(forKey: "settings.enableGifsicle") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "settings.enableGifsicle") }
    }
    
    var enableGifLossy: Bool {
        get { UserDefaults.standard.bool(forKey: "settings.enableGifLossy") }
        set { UserDefaults.standard.set(newValue, forKey: "settings.enableGifLossy") }
    }
    
    var compressImmediately: Bool {
        get { UserDefaults.standard.object(forKey: "settings.compressImmediately") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "settings.compressImmediately") }
    }
    
    var enableSvgcleaner: Bool {
        get { UserDefaults.standard.object(forKey: "settings.enableSvgcleaner") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "settings.enableSvgcleaner") }
    }
    
    var svgPrecision: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "settings.svgPrecision")
            return val == 0 ? 3 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.svgPrecision") }
    }
    
    var svgMultipass: Bool {
        get { UserDefaults.standard.bool(forKey: "settings.svgMultipass") }
        set { UserDefaults.standard.set(newValue, forKey: "settings.svgMultipass") }
    }
    
    // MARK: - Statistics Persistence
    
    var disableStatistics: Bool {
        get { UserDefaults.standard.bool(forKey: "stats.disableStatistics") }
        set { UserDefaults.standard.set(newValue, forKey: "stats.disableStatistics") }
    }
    
    var lifetimeCompressedCount: Int {
        get { UserDefaults.standard.integer(forKey: "stats.lifetimeCount") }
        set { UserDefaults.standard.set(newValue, forKey: "stats.lifetimeCount") }
    }
    
    var lifetimeOriginalBytes: Int {
        get { UserDefaults.standard.integer(forKey: "stats.lifetimeOriginal") }
        set { UserDefaults.standard.set(newValue, forKey: "stats.lifetimeOriginal") }
    }
    
    var lifetimeSavedBytes: Int {
        get { UserDefaults.standard.integer(forKey: "stats.lifetimeSaved") }
        set { UserDefaults.standard.set(newValue, forKey: "stats.lifetimeSaved") }
    }
    
    var formatSavingsData: Data {
        get { UserDefaults.standard.data(forKey: "stats.formatSavings") ?? Data() }
        set { UserDefaults.standard.set(newValue, forKey: "stats.formatSavings") }
    }
    
    // MARK: - Custom Compression Logic
    
    private var _customJpegQuality: Double {
        get { 
            let val = UserDefaults.standard.double(forKey: "settings.customJpegQuality")
            return val == 0 ? 0.84 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.customJpegQuality") }
    }
    
    private var _customPngLevel: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "settings.customPngLevel")
            return val == 0 ? 4 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.customPngLevel") }
    }
    
    private var _customAvifQuality: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "settings.advanced.customAvifQuality")
            return val == 0 ? 28 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.advanced.customAvifQuality") }
    }
    
    private var _customAvifSpeed: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "settings.advanced.customAvifSpeed")
            return val == 0 ? 3 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.advanced.customAvifSpeed") }
    }
    
    private var _customWebPQuality: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "settings.customWebPQuality")
            return val == 0 ? 88 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.customWebPQuality") }
    }
    
    private var _customWebPMethod: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "settings.customWebPMethod")
            return val == 0 ? 5 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.customWebPMethod") }
    }
    
    // MARK: - User Presets
    
    var userPresetsData: Data {
        get { UserDefaults.standard.data(forKey: "settings.userPresets") ?? Data() }
        set { UserDefaults.standard.set(newValue, forKey: "settings.userPresets") }
    }
    
    var activeUserPresetIdString: String {
        get { UserDefaults.standard.string(forKey: "settings.activeUserPresetId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "settings.activeUserPresetId") }
    }
    
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
        let newPreset = UserPreset(name: name, settings: self.settings)
        var current = userPresets
        current.append(newPreset)
        userPresets = current
        preset = .custom
        activeUserPresetId = newPreset.id
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
        _customWebPQuality = userPreset.customWebPQuality
        _customWebPMethod = userPreset.customWebPMethod
        enableSvgcleaner = userPreset.enableSvgcleaner
        svgPrecision = userPreset.svgPrecision
        svgMultipass = userPreset.svgMultipass
        enableGifsicle = userPreset.enableGifsicle
        preserveMetadata = userPreset.preserveMetadata
        convertToSRGB = userPreset.convertToSRGB
        preset = .custom
        activeUserPresetId = userPreset.id
    }
    
    // MARK: - Resizing Settings
    
    var resizeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "settings.resize.enabled") }
        set { UserDefaults.standard.set(newValue, forKey: "settings.resize.enabled") }
    }
    
    var resizeValue: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "settings.resize.value")
            return val == 0 ? 1920 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: "settings.resize.value") }
    }
    
    var resizeConditionRaw: String {
        get { UserDefaults.standard.string(forKey: "settings.resize.condition") ?? ResizeCondition.fit.rawValue }
        set { UserDefaults.standard.set(newValue, forKey: "settings.resize.condition") }
    }
    
    var resizeCondition: ResizeCondition {
        get { ResizeCondition(rawValue: resizeConditionRaw) ?? .fit }
        set { resizeConditionRaw = newValue.rawValue }
    }
    
    // MARK: - Public Accessors with Custom logic
    
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

    private func switchToCustomIfNeeded() {
        if preset != .custom {
            preset = .custom
        }
        if activeUserPresetId != nil {
            activeUserPresetId = nil
        }
    }
    
    var appearanceMode: AppearanceMode {
        get {
            access(keyPath: \.appearanceMode)
            return AppearanceMode(rawValue: appearanceModeRaw) ?? .auto
        }
        set {
            withMutation(keyPath: \.appearanceMode) {
                AppUIManager.shared.applyAppearance(newValue)
                appearanceModeRaw = newValue.rawValue
            }
        }
    }
    
    var language: AppLanguage {
        get {
            access(keyPath: \.language)
            return AppLanguage(rawValue: languageRaw) ?? .auto
        }
        set {
            withMutation(keyPath: \.language) {
                languageRaw = newValue.rawValue
                LanguageManager.shared.applyLanguage(newValue)
            }
        }
    }
    
    var preset: CompressionPreset {
        get {
            access(keyPath: \.preset)
            return CompressionPreset(rawValue: presetRaw) ?? .balanced
        }
        set { 
            withMutation(keyPath: \.preset) {
                presetRaw = newValue.rawValue
                if newValue != .custom {
                    applyPresetValues(newValue)
                    activeUserPresetId = nil
                }
            }
        }
    }
    
    private func applyPresetValues(_ preset: CompressionPreset) {
        switch preset {
        case .quality:
            _customJpegQuality = 0.92
            _customPngLevel = 4
            _customAvifQuality = 45
            _customAvifSpeed = 2
            _customWebPQuality = 95
            _customWebPMethod = 6
            svgPrecision = 4
            svgMultipass = false
        case .balanced:
            _customJpegQuality = 0.84
            _customPngLevel = 4
            _customAvifQuality = 28
            _customAvifSpeed = 3
            _customWebPQuality = 88
            _customWebPMethod = 5
            svgPrecision = 3
            svgMultipass = false
        case .saving:
            _customJpegQuality = 0.72
            _customPngLevel = 6 
            _customAvifQuality = 35
            _customAvifSpeed = 4
            _customWebPQuality = 82
            _customWebPMethod = 5
            svgPrecision = 2
            svgMultipass = true
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
        resizeCondition = .fit
        compressImmediately = true
        playSoundOnCompletion = true
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
        s.resizeCondition = resizeCondition
        s.compressImmediately = compressImmediately
        
        return s
    }

    var launchAtLoginProxy: Bool {
        get { launchAtLogin }
        set {
            launchAtLogin = newValue
            AppUIManager.shared.setLaunchAtLogin(newValue)
        }
    }

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
