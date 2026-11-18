import Foundation

/// An entry as plain values, for the smart helpers (no database).
struct EntryRecord: Sendable, Equatable {
    var kind: EntryKind
    var amount: Centimes
    var date: Date
    var merchant: String
    var categoryID: UUID?
}

extension EntryRecord {
    @MainActor init(_ entry: Entry) {
        self.init(kind: entry.kind, amount: entry.amount, date: entry.date, merchant: entry.merchant, categoryID: entry.category?.id)
    }
}

/// Remembers which category the user puts each shop in, from their own history.
enum CategoryMemory {
    /// "Café Clock!" → "CAFE CLOCK"
    static func key(_ merchant: String) -> String {
        let folded = ReceiptParser.fold(merchant)
        let kept = folded.map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// The category of the most recent expense at the same shop.
    static func category(for merchant: String, in records: [EntryRecord]) -> UUID? {
        let k = key(merchant)
        guard k.count >= 2 else { return nil }
        return records
            .filter { $0.kind == .expense && $0.categoryID != nil && key($0.merchant) == k }
            .max { $0.date < $1.date }?
            .categoryID
    }
}

/// Finds an expense that looks already added: same amount, same or next day, same shop (or no shop).
enum DuplicateCheck {
    static func find(amount: Centimes, date: Date, merchant: String, in records: [EntryRecord],
                     calendar: Calendar = .current) -> EntryRecord? {
        let k = CategoryMemory.key(merchant)
        let day = calendar.startOfDay(for: date)
        return records.first { r in
            guard r.kind == .expense, r.amount == amount else { return false }
            let other = calendar.startOfDay(for: r.date)
            let gap = abs(calendar.dateComponents([.day], from: day, to: other).day ?? 99)
            guard gap <= 1 else { return false }
            let rk = CategoryMemory.key(r.merchant)
            return k.isEmpty || rk.isEmpty || k == rk
        }
    }
}

/// What "Type it" understood from a short phrase like "taxi 20" or "khlst 50 f l9hwa".
struct QuickEntry: Equatable, Sendable {
    var kind: EntryKind = .expense
    var amount: Centimes?
    var categoryKey: String?
    var incomeSource: IncomeSource = .other
    /// Words left after removing the amount and filler words, used as the shop or note.
    var text: String = ""
}

/// Understands short French, English and Darija (Latin letters) phrases.
enum QuickEntryParser {
    private static let fillers: Set<String> = [
        "KHLST", "KHALLAST", "KHELLEST", "KHLLST", "KHELLST", "DFA3T", "DFAAT", "SRAFT", "SREFT", "SREFFT", "PAID", "SPENT",
        "PAYE", "J'AI", "JAI", "F", "FI", "L", "DYAL", "DIAL", "FOR", "ON", "AT", "POUR", "SUR", "DE", "DU", "LA", "LE",
        "AU", "EN", "A", "DH", "DHS", "MAD", "DIRHAM", "DIRHAMS", "ADD", "AJOUTE", "AJOUTER", "ZID", "+"
    ]

    private static let keywords: [(String, [String])] = [
        ("transport", ["TAXI", "TAXIS", "TRAM", "TRAMWAY", "BUS", "ESSENCE", "GASOIL", "GAZOIL", "CARBURANT", "TRAIN", "ONCF",
                       "CTM", "CAREEM", "INDRIVE", "YASSIR", "HEETCH", "PARKING", "PEAGE", "UBER"]),
        ("food", ["CAFE", "COFFEE", "QAHWA", "KAHWA", "L9HWA", "9HWA", "QHWA", "RESTO", "RESTAURANT", "GLOVO", "PIZZA", "TACOS",
                  "SNACK", "BURGER", "FTOUR", "DEJEUNER", "DINER", "LUNCH", "DINNER", "SANDWICH", "MCDO", "KFC", "ATAY", "JUS"]),
        ("courses", ["HANOUT", "7ANOUT", "MARJANE", "CARREFOUR", "BIM", "ACIMA", "COURSES", "KHODRA", "LKHODRA", "L7EM", "LHAM",
                     "KHOBZ", "PAIN", "LAIT", "EPICERIE", "GROCERIES", "SOUK", "MARCHE", "FRUITS", "LEGUMES"]),
        ("rent", ["LOYER", "RENT", "KRA", "LKRA"]),
        ("phone", ["INWI", "ORANGE", "IAM", "RECHARGE", "INTERNET", "FORFAIT", "PHONE", "TELEPHONE", "ADSL", "FIBRE"]),
        ("bills", ["LYDEC", "REDAL", "AMENDIS", "EAU", "ELECTRICITE", "DOW", "LMA", "FACTURE", "BILLS", "BILL", "GAZ", "BOUTA"]),
        ("goingout", ["CINEMA", "SORTIE", "FILM", "CONCERT", "MATCH", "NETFLIX", "SPOTIFY", "BAR", "CLUB"])
    ]

    private static let incomeWords: [String: IncomeSource] = [
        "SALAIRE": .salary, "SALARY": .salary, "KHLAS": .salary, "LKHLAS": .salary, "KHLASS": .salary, "PAIE": .salary,
        "FREELANCE": .freelance, "RENTREE": .other, "INCOME": .other
    ]

    static func parse(_ input: String) -> QuickEntry {
        var result = QuickEntry()
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return result }

        result.amount = ReceiptParser.amounts(in: trimmed).first
        let tokens = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let folded = tokens.map { ReceiptParser.fold($0).trimmingCharacters(in: .punctuationCharacters) }

        if trimmed.hasPrefix("+") { result.kind = .income }
        for f in folded {
            if let source = incomeWords[f] { result.kind = .income; result.incomeSource = source }
        }

        if result.kind == .expense {
            if let known = MerchantDirectory.match(in: [trimmed]) {
                result.categoryKey = known.categoryKey
            } else {
                result.categoryKey = keywords.first { _, words in folded.contains { words.contains($0) } }?.0
            }
        }

        let kept = zip(tokens, folded).filter { token, f in
            !fillers.contains(f) && !isAmountToken(f) && incomeWords[f] == nil && !f.isEmpty
        }.map { $0.0.trimmingCharacters(in: .punctuationCharacters) }
        var text = kept.joined(separator: " ")
        if let first = text.first { text = first.uppercased() + text.dropFirst() }
        result.text = text
        return result
    }

    /// "20", "112,50", "20dh", "+8000" are amounts, "l9hwa" is not.
    private static func isAmountToken(_ folded: String) -> Bool {
        guard folded.contains(where: \.isNumber) else { return false }
        let letters = String(folded.filter(\.isLetter))
        return ["", "DH", "DHS", "MAD"].contains(letters)
    }
}
