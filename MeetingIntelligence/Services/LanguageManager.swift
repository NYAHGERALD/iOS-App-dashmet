//
//  LanguageManager.swift
//  MeetingIntelligence
//
//  Multi-language support for speech recognition
//  Includes support for English variants including West African English
//

import Foundation
import Speech
import Combine

// MARK: - Supported Language
struct SupportedLanguage: Identifiable, Hashable {
    let id: String  // Locale identifier
    let name: String
    let nativeName: String
    let flag: String
    let region: String
    var isAvailable: Bool = true
    
    var displayName: String {
        if nativeName != name {
            return "\(flag) \(name) (\(nativeName))"
        }
        return "\(flag) \(name)"
    }
    
    var shortDisplayName: String {
        return "\(flag) \(name)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SupportedLanguage, rhs: SupportedLanguage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Language Category
enum LanguageCategory: String, CaseIterable {
    case english = "English"
    case european = "European"
    case african = "African"
    case asian = "Asian"
    case middleEastern = "Middle Eastern"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .english: return "globe.americas"
        case .european: return "globe.europe.africa"
        case .african: return "globe.europe.africa"
        case .asian: return "globe.asia.australia"
        case .middleEastern: return "globe.central.south.asia"
        case .other: return "globe"
        }
    }
}

// MARK: - Language Manager
@MainActor
class LanguageManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = LanguageManager()
    
    // MARK: - Published Properties
    @Published var selectedLanguage: SupportedLanguage
    @Published var recentLanguages: [SupportedLanguage] = []
    @Published var availableLanguages: [SupportedLanguage] = []
    
    // MARK: - Storage Keys
    private let selectedLanguageKey = "selectedLanguageId"
    private let recentLanguagesKey = "recentLanguageIds"
    
    // MARK: - All Supported Languages
    /// Comprehensive list of languages supported by Apple's Speech Recognition
    /// Includes Pidgin-friendly variants (Nigeria, Ghana) for West African users
    static let allLanguages: [SupportedLanguage] = [
        // English Variants (Prioritizing West African for Pidgin support)
        SupportedLanguage(id: "en-NG", name: "English (Nigeria)", nativeName: "Nigerian English", flag: "🇳🇬", region: "Africa"),
        SupportedLanguage(id: "en-GH", name: "English (Ghana)", nativeName: "Ghanaian English", flag: "🇬🇭", region: "Africa"),
        SupportedLanguage(id: "en-US", name: "English (US)", nativeName: "American English", flag: "🇺🇸", region: "North America"),
        SupportedLanguage(id: "en-GB", name: "English (UK)", nativeName: "British English", flag: "🇬🇧", region: "Europe"),
        SupportedLanguage(id: "en-AU", name: "English (Australia)", nativeName: "Australian English", flag: "🇦🇺", region: "Oceania"),
        SupportedLanguage(id: "en-CA", name: "English (Canada)", nativeName: "Canadian English", flag: "🇨🇦", region: "North America"),
        SupportedLanguage(id: "en-IN", name: "English (India)", nativeName: "Indian English", flag: "🇮🇳", region: "Asia"),
        SupportedLanguage(id: "en-ZA", name: "English (South Africa)", nativeName: "South African English", flag: "🇿🇦", region: "Africa"),
        SupportedLanguage(id: "en-IE", name: "English (Ireland)", nativeName: "Irish English", flag: "🇮🇪", region: "Europe"),
        SupportedLanguage(id: "en-NZ", name: "English (New Zealand)", nativeName: "New Zealand English", flag: "🇳🇿", region: "Oceania"),
        SupportedLanguage(id: "en-SG", name: "English (Singapore)", nativeName: "Singaporean English", flag: "🇸🇬", region: "Asia"),
        SupportedLanguage(id: "en-PH", name: "English (Philippines)", nativeName: "Philippine English", flag: "🇵🇭", region: "Asia"),
        SupportedLanguage(id: "en-KE", name: "English (Kenya)", nativeName: "Kenyan English", flag: "🇰🇪", region: "Africa"),
        
        // French Variants (Cameroon/West Africa)
        SupportedLanguage(id: "fr-CM", name: "French (Cameroon)", nativeName: "Français Camerounais", flag: "🇨🇲", region: "Africa"),
        SupportedLanguage(id: "fr-FR", name: "French (France)", nativeName: "Français", flag: "🇫🇷", region: "Europe"),
        SupportedLanguage(id: "fr-CA", name: "French (Canada)", nativeName: "Français Canadien", flag: "🇨🇦", region: "North America"),
        SupportedLanguage(id: "fr-BE", name: "French (Belgium)", nativeName: "Français Belge", flag: "🇧🇪", region: "Europe"),
        SupportedLanguage(id: "fr-CH", name: "French (Switzerland)", nativeName: "Français Suisse", flag: "🇨🇭", region: "Europe"),
        
        // Spanish Variants
        SupportedLanguage(id: "es-ES", name: "Spanish (Spain)", nativeName: "Español", flag: "🇪🇸", region: "Europe"),
        SupportedLanguage(id: "es-MX", name: "Spanish (Mexico)", nativeName: "Español Mexicano", flag: "🇲🇽", region: "North America"),
        SupportedLanguage(id: "es-US", name: "Spanish (US)", nativeName: "Español US", flag: "🇺🇸", region: "North America"),
        SupportedLanguage(id: "es-AR", name: "Spanish (Argentina)", nativeName: "Español Argentino", flag: "🇦🇷", region: "South America"),
        SupportedLanguage(id: "es-CO", name: "Spanish (Colombia)", nativeName: "Español Colombiano", flag: "🇨🇴", region: "South America"),
        
        // German Variants
        SupportedLanguage(id: "de-DE", name: "German (Germany)", nativeName: "Deutsch", flag: "🇩🇪", region: "Europe"),
        SupportedLanguage(id: "de-AT", name: "German (Austria)", nativeName: "Österreichisches Deutsch", flag: "🇦🇹", region: "Europe"),
        SupportedLanguage(id: "de-CH", name: "German (Switzerland)", nativeName: "Schweizerdeutsch", flag: "🇨🇭", region: "Europe"),
        
        // Portuguese Variants
        SupportedLanguage(id: "pt-BR", name: "Portuguese (Brazil)", nativeName: "Português Brasileiro", flag: "🇧🇷", region: "South America"),
        SupportedLanguage(id: "pt-PT", name: "Portuguese (Portugal)", nativeName: "Português", flag: "🇵🇹", region: "Europe"),
        
        // Chinese Variants
        SupportedLanguage(id: "zh-CN", name: "Chinese (Simplified)", nativeName: "简体中文", flag: "🇨🇳", region: "Asia"),
        SupportedLanguage(id: "zh-TW", name: "Chinese (Traditional)", nativeName: "繁體中文", flag: "🇹🇼", region: "Asia"),
        SupportedLanguage(id: "zh-HK", name: "Chinese (Hong Kong)", nativeName: "廣東話", flag: "🇭🇰", region: "Asia"),
        
        // Japanese
        SupportedLanguage(id: "ja-JP", name: "Japanese", nativeName: "日本語", flag: "🇯🇵", region: "Asia"),
        
        // Korean
        SupportedLanguage(id: "ko-KR", name: "Korean", nativeName: "한국어", flag: "🇰🇷", region: "Asia"),
        
        // Arabic Variants
        SupportedLanguage(id: "ar-SA", name: "Arabic (Saudi Arabia)", nativeName: "العربية", flag: "🇸🇦", region: "Middle East"),
        SupportedLanguage(id: "ar-AE", name: "Arabic (UAE)", nativeName: "العربية الإماراتية", flag: "🇦🇪", region: "Middle East"),
        SupportedLanguage(id: "ar-EG", name: "Arabic (Egypt)", nativeName: "العربية المصرية", flag: "🇪🇬", region: "Middle East"),
        
        // Hindi
        SupportedLanguage(id: "hi-IN", name: "Hindi", nativeName: "हिन्दी", flag: "🇮🇳", region: "Asia"),
        
        // Italian
        SupportedLanguage(id: "it-IT", name: "Italian", nativeName: "Italiano", flag: "🇮🇹", region: "Europe"),
        
        // Dutch
        SupportedLanguage(id: "nl-NL", name: "Dutch", nativeName: "Nederlands", flag: "🇳🇱", region: "Europe"),
        SupportedLanguage(id: "nl-BE", name: "Dutch (Belgium)", nativeName: "Vlaams", flag: "🇧🇪", region: "Europe"),
        
        // Polish
        SupportedLanguage(id: "pl-PL", name: "Polish", nativeName: "Polski", flag: "🇵🇱", region: "Europe"),
        
        // Russian
        SupportedLanguage(id: "ru-RU", name: "Russian", nativeName: "Русский", flag: "🇷🇺", region: "Europe"),
        
        // Turkish
        SupportedLanguage(id: "tr-TR", name: "Turkish", nativeName: "Türkçe", flag: "🇹🇷", region: "Middle East"),
        
        // Thai
        SupportedLanguage(id: "th-TH", name: "Thai", nativeName: "ไทย", flag: "🇹🇭", region: "Asia"),
        
        // Vietnamese
        SupportedLanguage(id: "vi-VN", name: "Vietnamese", nativeName: "Tiếng Việt", flag: "🇻🇳", region: "Asia"),
        
        // Indonesian
        SupportedLanguage(id: "id-ID", name: "Indonesian", nativeName: "Bahasa Indonesia", flag: "🇮🇩", region: "Asia"),
        
        // Malay
        SupportedLanguage(id: "ms-MY", name: "Malay", nativeName: "Bahasa Melayu", flag: "🇲🇾", region: "Asia"),
        
        // Swedish
        SupportedLanguage(id: "sv-SE", name: "Swedish", nativeName: "Svenska", flag: "🇸🇪", region: "Europe"),
        
        // Norwegian
        SupportedLanguage(id: "nb-NO", name: "Norwegian", nativeName: "Norsk", flag: "🇳🇴", region: "Europe"),
        
        // Danish
        SupportedLanguage(id: "da-DK", name: "Danish", nativeName: "Dansk", flag: "🇩🇰", region: "Europe"),
        
        // Finnish
        SupportedLanguage(id: "fi-FI", name: "Finnish", nativeName: "Suomi", flag: "🇫🇮", region: "Europe"),
        
        // Hebrew
        SupportedLanguage(id: "he-IL", name: "Hebrew", nativeName: "עברית", flag: "🇮🇱", region: "Middle East"),
        
        // Greek
        SupportedLanguage(id: "el-GR", name: "Greek", nativeName: "Ελληνικά", flag: "🇬🇷", region: "Europe"),
        
        // Czech
        SupportedLanguage(id: "cs-CZ", name: "Czech", nativeName: "Čeština", flag: "🇨🇿", region: "Europe"),
        
        // Hungarian
        SupportedLanguage(id: "hu-HU", name: "Hungarian", nativeName: "Magyar", flag: "🇭🇺", region: "Europe"),
        
        // Romanian
        SupportedLanguage(id: "ro-RO", name: "Romanian", nativeName: "Română", flag: "🇷🇴", region: "Europe"),
        
        // Ukrainian
        SupportedLanguage(id: "uk-UA", name: "Ukrainian", nativeName: "Українська", flag: "🇺🇦", region: "Europe"),
        
        // Swahili (East Africa)
        SupportedLanguage(id: "sw-KE", name: "Swahili", nativeName: "Kiswahili", flag: "🇰🇪", region: "Africa"),
        
        // Afrikaans
        SupportedLanguage(id: "af-ZA", name: "Afrikaans", nativeName: "Afrikaans", flag: "🇿🇦", region: "Africa"),
    ]
    
    // MARK: - Initialization
    private init() {
        // Set default language (Nigerian English for Pidgin support)
        selectedLanguage = Self.allLanguages.first { $0.id == "en-NG" } ?? Self.allLanguages[0]
        
        // Load saved preferences
        loadPreferences()
        
        // Check availability on device
        checkAvailability()
    }
    
    // MARK: - Check Language Availability
    func checkAvailability() {
        let supportedLocales = SFSpeechRecognizer.supportedLocales()
        
        availableLanguages = Self.allLanguages.map { language in
            var updatedLanguage = language
            updatedLanguage.isAvailable = supportedLocales.contains(Locale(identifier: language.id))
            return updatedLanguage
        }.filter { $0.isAvailable }
        
        // If selected language is not available, fall back to en-US
        if !availableLanguages.contains(where: { $0.id == selectedLanguage.id }) {
            if let fallback = availableLanguages.first(where: { $0.id == "en-US" }) {
                selectedLanguage = fallback
            } else if let first = availableLanguages.first {
                selectedLanguage = first
            }
        }
        
        print("📍 Available languages: \(availableLanguages.count) out of \(Self.allLanguages.count)")
    }
    
    // MARK: - Language Selection
    func selectLanguage(_ language: SupportedLanguage) {
        guard language.isAvailable else { return }
        
        selectedLanguage = language
        
        // Add to recent languages
        addToRecent(language)
        
        // Save preferences
        savePreferences()
        
        print("🌍 Language selected: \(language.displayName)")
    }
    
    private func addToRecent(_ language: SupportedLanguage) {
        // Remove if already in recent
        recentLanguages.removeAll { $0.id == language.id }
        
        // Add to front
        recentLanguages.insert(language, at: 0)
        
        // Keep only last 5
        if recentLanguages.count > 5 {
            recentLanguages = Array(recentLanguages.prefix(5))
        }
    }
    
    // MARK: - Language Grouping
    func languagesByCategory() -> [LanguageCategory: [SupportedLanguage]] {
        var grouped: [LanguageCategory: [SupportedLanguage]] = [:]
        
        for language in availableLanguages {
            let category = categoryFor(language: language)
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(language)
        }
        
        return grouped
    }
    
    func englishVariants() -> [SupportedLanguage] {
        return availableLanguages.filter { $0.id.hasPrefix("en-") }
    }
    
    func africanLanguages() -> [SupportedLanguage] {
        return availableLanguages.filter { language in
            ["Africa"].contains(language.region) || 
            ["en-NG", "en-GH", "en-ZA", "en-KE", "fr-CM", "sw-KE", "af-ZA"].contains(language.id)
        }
    }
    
    private func categoryFor(language: SupportedLanguage) -> LanguageCategory {
        if language.id.hasPrefix("en-") {
            return .english
        }
        
        switch language.region {
        case "Africa":
            return .african
        case "Asia":
            return .asian
        case "Middle East":
            return .middleEastern
        case "Europe":
            return .european
        default:
            return .other
        }
    }
    
    // MARK: - Pidgin English Support Note
    /// Apple's Speech Recognition doesn't directly support Pidgin English.
    /// For Pidgin speakers from Cameroon and Nigeria, we recommend:
    /// 1. English (Nigeria) - en-NG - closest match
    /// 2. English (Ghana) - en-GH - also good for West African accent
    /// 3. AI correction service will help clean up and contextualize
    func pidginSupportedLanguages() -> [SupportedLanguage] {
        return availableLanguages.filter { ["en-NG", "en-GH", "en-KE", "en-ZA"].contains($0.id) }
    }
    
    // MARK: - Create Speech Recognizer
    func createSpeechRecognizer() -> SFSpeechRecognizer? {
        let locale = Locale(identifier: selectedLanguage.id)
        return SFSpeechRecognizer(locale: locale)
    }
    
    // MARK: - Persistence
    private func savePreferences() {
        UserDefaults.standard.set(selectedLanguage.id, forKey: selectedLanguageKey)
        UserDefaults.standard.set(recentLanguages.map { $0.id }, forKey: recentLanguagesKey)
    }
    
    private func loadPreferences() {
        // Load selected language
        if let savedId = UserDefaults.standard.string(forKey: selectedLanguageKey),
           let saved = Self.allLanguages.first(where: { $0.id == savedId }) {
            selectedLanguage = saved
        }
        
        // Load recent languages
        if let savedIds = UserDefaults.standard.array(forKey: recentLanguagesKey) as? [String] {
            recentLanguages = savedIds.compactMap { id in
                Self.allLanguages.first { $0.id == id }
            }
        }
    }
    
    // MARK: - Search
    func searchLanguages(_ query: String) -> [SupportedLanguage] {
        guard !query.isEmpty else { return availableLanguages }
        
        let lowercased = query.lowercased()
        return availableLanguages.filter { language in
            language.name.lowercased().contains(lowercased) ||
            language.nativeName.lowercased().contains(lowercased) ||
            language.region.lowercased().contains(lowercased) ||
            language.id.lowercased().contains(lowercased)
        }
    }
}
