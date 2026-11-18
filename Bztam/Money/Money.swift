import Foundation

/// Amounts are always whole centimes (`Int`). 1 DH = 100 centimes. Never `Double` for money.
typealias Centimes = Int

enum Money {
    /// Currency suffix shown after amounts.
    static let currencySymbol = "DH"

    /// "2,760 DH" (en) or "2 760 DH" (fr). Decimals only when there are centimes: "245.50 DH" / "245,50 DH".
    static func format(_ amount: Centimes, language: String = L10n.code, sign: Bool = false, symbol: Bool = true) -> String {
        let negative = amount < 0
        let absolute = abs(amount)
        let units = absolute / 100
        let cents = absolute % 100
        let grouping = language == "fr" ? "\u{202F}" : ","
        let decimal = language == "fr" ? "," : "."

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
        var result = grouped
        if negative { result = "−" + result } else if sign && amount > 0 { result = "+" + result }
        if symbol { result += " " + currencySymbol }
        return result
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
