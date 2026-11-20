import Foundation

/// Amounts are always whole centimes (`Int`). 1 DH = 100 centimes. Never `Double` for money.
typealias Centimes = Int

/// Currencies the user can pick in Settings. Amounts are never converted; only the label changes.
enum Currency: String, CaseIterable, Identifiable, Sendable {
    case mad, eur, usd, gbp, cad, chf, sar, aed
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .mad: "DH"
        case .eur: "€"
        case .usd: "$"
        case .gbp: "£"
        case .cad: "CA$"
        case .chf: "CHF"
        case .sar: "SAR"
        case .aed: "AED"
        }
    }

    var title: String {
        switch self {
        case .mad: L10n.t("Moroccan dirham (DH)")
        case .eur: L10n.t("Euro (€)")
        case .usd: L10n.t("US dollar ($)")
        case .gbp: L10n.t("British pound (£)")
        case .cad: L10n.t("Canadian dollar (CA$)")
        case .chf: L10n.t("Swiss franc (CHF)")
        case .sar: L10n.t("Saudi riyal (SAR)")
        case .aed: L10n.t("UAE dirham (AED)")
        }
    }

    /// English writes £245.50, $12 and €9; French and Arabic put every symbol after the number, like "245,50 £".
    func symbolFirst(language: String) -> Bool {
        language == "en" && [.eur, .usd, .gbp, .cad].contains(self)
    }
}

/// Which amounts privacy mode hides.
enum AmountPrivacy: Sendable {
    /// Ordinary amounts (expenses, budgets): hidden only when "hide all amounts" is chosen.
    case any
    /// Money in and what's left (they reveal the salary): hidden in both privacy settings.
    case income
    /// Never hidden (exports the user asked for).
    case never
}

enum Money {
    static let currencyKey = "currency"
    /// Privacy mode is on right now (the eye on Home).
    static let hiddenKey = "amountsHidden"
    /// Privacy mode hides only money in and what's left.
    static let hideIncomeOnlyKey = "hideIncomeOnly"
    /// Turn privacy mode on each time Bztam opens.
    static let hideOnOpenKey = "hideAmountsOnOpen"

    static var currency: Currency {
        Currency(rawValue: UserDefaults.standard.string(forKey: currencyKey) ?? "") ?? .mad
    }

    /// Currency label shown with amounts.
    static var currencySymbol: String { currency.symbol }

    static func isHidden(_ privacy: AmountPrivacy) -> Bool {
        let d = UserDefaults.standard
        guard privacy != .never, d.bool(forKey: hiddenKey) else { return false }
        return privacy == .income || !d.bool(forKey: hideIncomeOnlyKey)
    }

    /// "2,760 DH" (en) or "2 760 DH" (fr). Decimals only when there are centimes: "245.50 DH" / "245,50 DH".
    /// With privacy mode on, the number becomes "••••".
    static func format(_ amount: Centimes, language: String = L10n.code, sign: Bool = false, symbol: Bool = true,
                       privacy: AmountPrivacy = .any) -> String {
        let negative = amount < 0
        let absolute = abs(amount)
        let units = absolute / 100
        let cents = absolute % 100
        let grouping = language == "en" ? "," : "\u{202F}"
        let decimal = language == "en" ? "." : ","

        var digits = String(units)
        var grouped = ""
        while digits.count > 3 {
            let tail = String(digits.suffix(3))
            grouped = grouping + tail + grouped
            digits.removeLast(3)
        }
        grouped = digits + grouped
        if cents > 0 {
            grouped += decimal + (cents < 10 ? "0\(cents)" : "\(cents)")
        }
        if isHidden(privacy) { grouped = "••••" }
        var signText = ""
        if negative { signText = "−" } else if sign && amount > 0 { signText = "+" }
        let text: String
        if !symbol {
            text = signText + grouped
        } else {
            text = currency.symbolFirst(language: language)
                ? signText + currencySymbol + grouped
                : signText + grouped + " " + currencySymbol
        }
        // In Arabic, keep "2 310 DH" together as one left-to-right piece inside right-to-left sentences.
        return language == "ar" ? "\u{2066}" + text + "\u{2069}" : text
    }
}

/// What the user types on the amount keypad, kept as text so "12," or "0,5" stay visible while typing.
struct AmountInput: Equatable, Sendable {
    private(set) var text: String = ""

    static let maxUnitsDigits = 7

    init(text: String = "") { self.text = text }

    init(centimes: Centimes) {
        if centimes <= 0 { text = ""; return }
        let units = centimes / 100, cents = centimes % 100
        if cents == 0 { text = "\(units)" }
        else if cents % 10 == 0 { text = "\(units),\(cents / 10)" }
        else { text = "\(units),\(cents < 10 ? "0" : "")\(cents)" }
    }

    var hasDecimal: Bool { text.contains(",") }

    /// Adds one keypad key: a digit, "," or "⌫".
    mutating func press(_ key: String) {
        switch key {
        case "⌫":
            if !text.isEmpty { text.removeLast() }
        case ",", ".":
            guard !hasDecimal else { return }
            text = (text.isEmpty ? "0" : text) + ","
        default:
            guard key.count == 1, key.first?.isNumber == true else { return }
            if let comma = text.firstIndex(of: ",") {
                guard text[text.index(after: comma)...].count < 2 else { return }
                text += key
            } else {
                if text == "0" { text = key; return }
                guard text.count < Self.maxUnitsDigits else { return }
                text += key
            }
        }
    }

    /// The typed amount in centimes (0 when empty).
    var centimes: Centimes {
        guard !text.isEmpty else { return 0 }
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        let units = Int(parts[0]) ?? 0
        var cents = 0
        if parts.count > 1 {
            let frac = String(parts[1])
            if frac.count == 1 { cents = (Int(frac) ?? 0) * 10 }
            else if frac.count >= 2 { cents = Int(frac.prefix(2)) ?? 0 }
        }
        return units * 100 + cents
    }

    /// Text shown on screen, with the right decimal separator for the language.
    func display(language: String = L10n.code) -> String {
        if text.isEmpty { return "0" }
        return language == "fr" ? text : text.replacingOccurrences(of: ",", with: ".")
    }
}
