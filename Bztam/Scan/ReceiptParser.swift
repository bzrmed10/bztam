import Foundation

/// What was read from a receipt, a bill screenshot or a PDF. Every field may be missing; the user confirms.
struct ReceiptDraft: Equatable, Sendable {
    enum Confidence: Sendable, Equatable {
        /// Found next to a total keyword ("TOTAL TTC", "NET À PAYER"…).
        case high
        /// Guessed: the largest amount marked with DH/MAD.
        case low
        /// Nothing found.
        case none
    }

    var amount: Centimes?
    var date: Date?
    var merchant: String?
    /// Key of a default category ("courses", "phone"…), when the shop or the words suggest one.
    var categoryKey: String?
    var confidence: Confidence = .none
    /// Index of the line the total came from.
    var totalLineIndex: Int?

    /// True when this is very likely a bill or receipt (used before suggesting a new screenshot).
    var looksLikeBill: Bool { confidence == .high && amount != nil }
}

/// Reads totals, dates and shops from recognized text lines. Pure and unit-tested; no Vision, no UI.
/// Written for Moroccan receipts and bills in French and English (comma decimals, DH/MAD, day-first dates).
enum ReceiptParser {

    // MARK: - Entry point

    static func parse(lines rawLines: [String], now: Date = .now, calendar: Calendar = .current) -> ReceiptDraft {
        let lines = rawLines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var draft = ReceiptDraft()

        if let total = total(in: lines) {
            draft.amount = total.amount
            draft.confidence = total.confidence
            draft.totalLineIndex = total.line
        }
        draft.date = date(in: lines, now: now, calendar: calendar)
        if let known = MerchantDirectory.match(in: lines) {
            draft.merchant = known.name
            draft.categoryKey = known.categoryKey
        } else {
            draft.merchant = genericMerchant(in: lines)
            draft.categoryKey = MerchantDirectory.categoryHint(in: lines)
        }
        return draft
    }

    // MARK: - Total

    private static let strongKeywords = [
        "NET A PAYER", "TOTAL A PAYER", "MONTANT A PAYER", "TOTAL TTC", "MONTANT TTC", "TOTAL DUE",
        "AMOUNT DUE", "MONTANT TOTAL", "TOTAL PAYE", "MONTANT PAYE", "A PAYER", "GRAND TOTAL"
    ]
    private static let weakKeywords = ["TOTAL", "MONTANT", "AMOUNT", "SOMME", "TOTAL AMOUNT"]
    private static let excluded = [
        "SOUS-TOTAL", "SOUS TOTAL", "SUBTOTAL", "SUB TOTAL", "SUB-TOTAL", "TOTAL HT", "MONTANT HT", "TVA", "VAT",
        "REMISE", "RENDU", "MONNAIE", "ARTICLES", "ARTICLE", "QTE", "POINTS", "FIDELITE", "ECONOMIE", "ECONOMISE", "TAX"
    ]
    private static let currencyMarkers = ["DH", "DHS", "MAD", "DIRHAM", "DIRHAMS"]

    struct Total: Equatable {
        var amount: Centimes
        var confidence: ReceiptDraft.Confidence
        var line: Int
    }

    static func total(in lines: [String]) -> Total? {
        var best: (priority: Int, amount: Centimes, line: Int)?
        for (index, line) in lines.enumerated() {
            let folded = fold(line)
            guard !excluded.contains(where: { containsWord($0, in: folded) }) else { continue }
            let priority: Int
            if strongKeywords.contains(where: { containsWord($0, in: folded) }) { priority = 2 }
            else if weakKeywords.contains(where: { containsWord($0, in: folded) }) { priority = 1 }
            else { continue }

            var amount = amounts(in: line).last
            if amount == nil, index + 1 < lines.count, !looksLikeDateOrPhone(lines[index + 1]) {
                amount = amounts(in: lines[index + 1]).last
            }
            guard let found = amount, found > 0 else { continue }
            if let b = best {
                if priority > b.priority || (priority == b.priority && found > b.amount) {
                    best = (priority, found, index)
                }
            } else {
                best = (priority, found, index)
            }
        }
        if let b = best { return Total(amount: b.amount, confidence: .high, line: b.line) }

        // Fallback: the largest amount on a line marked with a currency.
        var fallback: (amount: Centimes, line: Int)?
        for (index, line) in lines.enumerated() {
            let folded = fold(line)
            guard currencyMarkers.contains(where: { containsWord($0, in: folded) }),
                  !excluded.contains(where: { containsWord($0, in: folded) }),
                  let a = amounts(in: line).max(), a > 0 else { continue }
            if fallback == nil || a > fallback!.amount { fallback = (a, index) }
        }
        if let f = fallback { return Total(amount: f.amount, confidence: .low, line: f.line) }
        return nil
    }

    /// Every amount on a line, in centimes, left to right. Understands 245,50 · 245.50 · 1 234,56 · 1.234,56 · 1,234.56.
    static func amounts(in line: String) -> [Centimes] {
        // Remove dates and times first so "17/11/2026 18:42" never reads as amounts.
        var cleaned = line
        for pattern in [#"\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}"#, #"\d{1,2}:\d{2}(:\d{2})?"#, #"\d{4}-\d{1,2}-\d{1,2}"#] {
            cleaned = replace(pattern, in: cleaned, with: " ")
        }
        let pattern = #"(?<![\d.,])(\d{1,3}(?:[ \x{00A0}\x{202F}.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)(?![\d])"#
        return matches(pattern, in: cleaned).compactMap { parseAmount($0.first ?? "") }
    }

    static func parseAmount(_ token: String) -> Centimes? {
        var s = token.filter { !$0.isWhitespace && $0 != "\u{00A0}" && $0 != "\u{202F}" }
        guard !s.isEmpty else { return nil }
        let hasDot = s.contains("."), hasComma = s.contains(",")
        var integerPart = s, fractionPart = ""
        if hasDot && hasComma {
            let decimal: Character = s.lastIndex(of: ".")! > s.lastIndex(of: ",")! ? "." : ","
            let thousands: Character = decimal == "." ? "," : "."
            s.removeAll { $0 == thousands }
            let parts = s.split(separator: decimal, omittingEmptySubsequences: false)
            integerPart = String(parts[0]); fractionPart = parts.count > 1 ? String(parts[1]) : ""
        } else if hasDot || hasComma {
            let sep: Character = hasDot ? "." : ","
            let parts = s.split(separator: sep, omittingEmptySubsequences: false)
            if parts.count == 2, (1...2).contains(parts[1].count) {
                integerPart = String(parts[0]); fractionPart = String(parts[1])
            } else {
                // Thousands separators only ("1.234" or "1,234,567").
                integerPart = parts.joined()
            }
        }
        guard let units = Int(integerPart), integerPart.count <= 7 else { return nil }
        var cents = 0
        if !fractionPart.isEmpty {
            guard let f = Int(fractionPart) else { return nil }
            cents = fractionPart.count == 1 ? f * 10 : f
        }
        let value = units * 100 + cents
        return value > 0 ? value : nil
    }

    // MARK: - Date

    private static let months: [String: Int] = [
        "JAN": 1, "JANV": 1, "JANVIER": 1, "JANUARY": 1,
        "FEV": 2, "FEVR": 2, "FEVRIER": 2, "FEB": 2, "FEBRUARY": 2,
        "MAR": 3, "MARS": 3, "MARCH": 3,
        "AVR": 4, "AVRIL": 4, "APR": 4, "APRIL": 4,
        "MAI": 5, "MAY": 5,
        "JUIN": 6, "JUN": 6, "JUNE": 6,
        "JUIL": 7, "JUILLET": 7, "JUL": 7, "JULY": 7,
        "AOUT": 8, "AUG": 8, "AUGUST": 8,
        "SEP": 9, "SEPT": 9, "SEPTEMBRE": 9, "SEPTEMBER": 9,
        "OCT": 10, "OCTOBRE": 10, "OCTOBER": 10,
        "NOV": 11, "NOVEMBRE": 11, "NOVEMBER": 11,
        "DEC": 12, "DECEMBRE": 12, "DECEMBER": 12
    ]

    static func date(in lines: [String], now: Date = .now, calendar: Calendar = .current) -> Date? {
        for line in lines {
            let folded = fold(line)
            for m in matches(#"(?<!\d)(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})(?!\d)"#, in: folded) where m.count == 4 {
                if let d = makeDate(day: Int(m[1]), month: Int(m[2]), year: Int(m[3]), now: now, calendar: calendar) { return d }
            }
            for m in matches(#"(?<!\d)(\d{4})-(\d{1,2})-(\d{1,2})(?!\d)"#, in: folded) where m.count == 4 {
                if let d = makeDate(day: Int(m[3]), month: Int(m[2]), year: Int(m[1]), now: now, calendar: calendar) { return d }
            }
            for m in matches(#"(?<!\d)(\d{1,2})\s+([A-Z]{3,9})\.?\s+(\d{4})(?!\d)"#, in: folded) where m.count == 4 {
                if let month = months[m[2]],
                   let d = makeDate(day: Int(m[1]), month: month, year: Int(m[3]), now: now, calendar: calendar) { return d }
            }
        }
        return nil
    }

    private static func makeDate(day: Int?, month: Int?, year: Int?, now: Date, calendar: Calendar) -> Date? {
        guard let day, let month, var year, (1...31).contains(day), (1...12).contains(month) else { return nil }
        if year < 100 { year += 2000 }
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
              calendar.component(.day, from: date) == day else { return nil }
        let earliest = calendar.date(byAdding: .year, value: -2, to: now) ?? now
        let latest = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return (earliest...latest).contains(date) ? date : nil
    }

    // MARK: - Merchant (when not in the directory)

    private static let skipWords = [
        "TICKET", "FACTURE", "RECU", "BIENVENUE", "WELCOME", "MERCI", "CAISSE", "CAISSIER", "TEL", "TELEPHONE",
        "ICE", "RC", "PATENTE", "IF", "CNSS", "DATE", "HEURE", "CLIENT", "N°", "NO", "COMMANDE", "ORDER", "RECEIPT", "INVOICE"
    ]

    static func genericMerchant(in lines: [String]) -> String? {
        for line in lines.prefix(6) {
            let folded = fold(line)
            let letters = line.filter(\.isLetter).count
            guard letters >= 3, Double(letters) / Double(max(line.count, 1)) > 0.5,
                  !skipWords.contains(where: { containsWord($0, in: folded) }),
                  !looksLikeDateOrPhone(line) else { continue }
            return titleCase(line)
        }
        return nil
    }

    // MARK: - Helpers

    /// Upper case without accents: "Net à payer" → "NET A PAYER".
    static func fold(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr")).uppercased()
    }

    /// Whole-word match on folded text ("BIM" does not match "BIMO").
    static func containsWord(_ word: String, in folded: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: word)
        return !matches("(?<![A-Z0-9])" + escaped + "(?![A-Z0-9])", in: folded).isEmpty
    }

    static func looksLikeDateOrPhone(_ line: String) -> Bool {
        let digits = line.filter(\.isNumber).count
        if !matches(#"\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}"#, in: line).isEmpty { return true }
        return digits >= 9 && Double(digits) / Double(max(line.count, 1)) > 0.6
    }

    private static func titleCase(_ s: String) -> String {
        s.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    /// All matches of a pattern; each match lists the whole match then its groups.
    static func matches(_ pattern: String, in s: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = s as NSString
        return regex.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { result in
            (0..<result.numberOfRanges).map { i in
                let r = result.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }

    private static func replace(_ pattern: String, in s: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return s }
        return regex.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: (s as NSString).length), withTemplate: template)
    }
}
