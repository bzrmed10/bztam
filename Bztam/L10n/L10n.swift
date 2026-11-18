import Foundation

/// Languages the app can show. `system` follows the phone and falls back to English.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system, en, fr
    var id: String { rawValue }

    /// Each language is written in itself so people can find theirs.
    var nativeName: String {
        switch self {
        case .system: L10n.t("Phone language")
        case .en: "English"
        case .fr: "Français"
        }
    }
}

/// Text lookup and formatting. English text is the key; `Strings.table` holds French.
enum L10n {
    static let storageKey = "appLanguage"
    static let supported = ["en", "fr"]

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

    /// The language in use: "en" or "fr".
    static var code: String {
        let s = selected
        return s == .system ? systemCode : s.rawValue
    }

    static var locale: Locale { Locale(identifier: code == "fr" ? "fr_MA" : "en_US") }

    static func t(_ key: String, language: String? = nil) -> String {
        let code = language ?? self.code
        guard code != "en" else { return key }
        guard let value = Strings.table[key], !value.isEmpty else { return key }
        return value
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), locale: locale, arguments: args)
    }
}
