import Foundation
import AppKit

final class LanguageManager {
    static let shared = LanguageManager()
    
    private init() {}
    
    func applyLanguage(_ language: AppLanguage) {
        let selectedLanguage: String
        
        switch language {
        case .auto:
            // When auto, we remove the override to let system decide
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
            return
        case .english: selectedLanguage = "en"
        case .russian: selectedLanguage = "ru"
        case .german: selectedLanguage = "de"
        case .spanish: selectedLanguage = "es"
        case .french: selectedLanguage = "fr"
        case .portuguese: selectedLanguage = "pt-BR"
        case .chinese: selectedLanguage = "zh-Hans"
        case .japanese: selectedLanguage = "ja"
        case .arabic: selectedLanguage = "ar"
        case .hindi: selectedLanguage = "hi"
        case .bengali: selectedLanguage = "bn"
        case .urdu: selectedLanguage = "ur"
        }
        
        UserDefaults.standard.set([selectedLanguage], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
    
    var systemLanguageDisplayName: String {
        let languageCode: String
        if #available(macOS 13, iOS 16, tvOS 16, watchOS 9, *) {
            languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        } else {
            languageCode = Locale.current.languageCode ?? "en"
        }
        return Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
    }
    
    func getCurrentLanguageDisplayName(for language: AppLanguage) -> String {
        switch language {
        case .auto:
            return NSLocalizedString("System Language", comment: "") + " (\(systemLanguageDisplayName))"
        default:
            return language.displayName
        }
    }
}

enum AppLanguage: String, CaseIterable {
    case auto = "auto"
    case english = "en"
    case russian = "ru"
    case german = "de"
    case spanish = "es"
    case french = "fr"
    case portuguese = "pt-BR"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case arabic = "ar"
    case hindi = "hi"
    case bengali = "bn"
    case urdu = "ur"
    
    var displayName: String {
        switch self {
        case .auto: return NSLocalizedString("Auto", comment: "")
        case .english: return "English"
        case .russian: return "Русский"
        case .german: return "Deutsch"
        case .spanish: return "Español"
        case .french: return "Français"
        case .portuguese: return "Português"
        case .chinese: return "简体中文"
        case .japanese: return "日本語"
        case .arabic: return "العربية"
        case .hindi: return "हिन्दी"
        case .bengali: return "বাংলা"
        case .urdu: return "اردو"
        }
    }
}
