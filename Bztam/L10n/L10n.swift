import Foundation

/// Languages the app can show. `system` follows the phone and falls back to English.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, en, fr, ar
    var id: String { rawValue }

    /// Each language is written in itself so people can find theirs.
    var nativeName: String {
        switch self {
        case .system: L10n.t("Phone language")
        case .en: "English"
        case .fr: "Français"
        case .ar: "العربية"
        }
    }
}

/// Text lookup and formatting. English text is the key; `Strings.table` holds French, `StringsArabic.table` Arabic.
enum L10n {
    static let storageKey = "appLanguage"
    static let supported = ["en", "fr", "ar"]

    /// The chosen language. A launch argument `-appLanguage fr` wins (UI tests use it).
    static var selected: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey), let l = AppLanguage(rawValue: raw) { return l }
        return .system
    }

    static func select(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
    }

    /// The first phone language we have a translation for, else English.
    static var systemCode: String {
        for preferred in Locale.preferredLanguages {
            let base = String(preferred.prefix(2))
            if supported.contains(base) { return base }
        }
        return "en"
    }

    /// The language in use: "en", "fr" or "ar".
    static var code: String {
        let s = selected
        return s == .system ? systemCode : s.rawValue
    }

    /// ar_MA keeps Western digits (0-9), as used in Morocco.
    static var locale: Locale { Locale(identifier: code == "fr" ? "fr_MA" : code == "ar" ? "ar_MA" : "en_US") }

    static var isRightToLeft: Bool { code == "ar" }

    static func t(_ key: String, language: String? = nil) -> String {
        let code = language ?? self.code
        guard code != "en" else { return key }
        let table = code == "ar" ? StringsArabic.table : Strings.table
        guard let value = table[key], !value.isEmpty else { return key }
        return value
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: locale, arguments: args)
    }
}
