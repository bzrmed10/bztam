import Foundation
import SwiftData

/// Reads a CSV made by Bztam's export (any language) back into entries. Pure parsing, unit-tested;
/// `apply` adds what isn't already there.
enum BackupImport {
    struct Row: Equatable, Sendable {
        var date: Date
        var kind: EntryKind
        var amount: Centimes
        var category: String
        var title: String
        var note: String
    }

    struct Preview: Equatable, Sendable {
        var rows: [Row]
        /// Lines that couldn't be read (not a date, not an amount).
        var unreadable: Int
    }

    enum Failure: Error, Equatable { case notBztam, empty }

    /// Splits CSV text into fields, with quotes ("a, b") and doubled quotes ("say ""hi""").
    static func fields(_ text: String, separator: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var chars = Array(text)
        if chars.first == "\u{FEFF}" { chars.removeFirst() }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 } else { quoted = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                quoted = true
            } else if c == separator {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r" || c == "\r\n" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            } else {
                field.append(c)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    /// "245.50", "245,50", "-3000.00" → centimes (sign kept).
    static func amount(_ text: String) -> Centimes? {
        let cleaned = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\u{202F}", with: "").replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "−", with: "-")
        guard let value = Decimal(string: cleaned, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        return NSDecimalNumber(decimal: value * 100).rounding(accordingToBehavior: nil).intValue
    }

    static func day(_ text: String, calendar: Calendar = .current) -> Date? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    /// The header Bztam writes, in every language: "Date, Type, Amount…".
    static func isBztamHeader(_ row: [String]) -> Bool {
        guard row.count >= 3 else { return false }
        let dateWords = L10n.supported.map { L10n.t("Date", language: $0).lowercased() }
        let amountWords = L10n.supported.map { L10n.t("Amount", language: $0).lowercased() }
        return dateWords.contains(row[0].trimmingCharacters(in: .whitespaces).lowercased())
            && amountWords.contains(row[2].trimmingCharacters(in: .whitespaces).lowercased())
    }

    static func preview(_ text: String, calendar: Calendar = .current) throws -> Preview {
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let separator: Character = firstLine.filter { $0 == ";" }.count > firstLine.filter { $0 == "," }.count ? ";" : ","
        let table = fields(text, separator: separator)
        guard let header = table.first, isBztamHeader(header) else { throw Failure.notBztam }
        var rows: [Row] = []
        var unreadable = 0
        for line in table.dropFirst() {
            guard line.count >= 3, let date = day(line[0], calendar: calendar), let signed = amount(line[2]), signed != 0 else {
                unreadable += 1
                continue
            }
            rows.append(Row(date: date, kind: signed < 0 ? .expense : .income, amount: abs(signed),
                            category: line.count > 4 ? line[4] : "",
                            title: line.count > 5 ? line[5] : "",
                            note: line.count > 6 ? line[6] : ""))
        }
        guard !rows.isEmpty else { throw Failure.empty }
        return Preview(rows: rows, unreadable: unreadable)
    }

    /// Same kind, amount, day and shop: already in Bztam.
    static func key(kind: EntryKind, amount: Centimes, date: Date, title: String, calendar: Calendar = .current) -> String {
        let d = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(kind.rawValue)|\(amount)|\(d.year ?? 0)-\(d.month ?? 0)-\(d.day ?? 0)|\(title.lowercased().trimmingCharacters(in: .whitespaces))"
    }

    /// The rows not already in Bztam.
    static func newRows(_ rows: [Row], existing: Set<String>, calendar: Calendar = .current) -> [Row] {
        var seen = existing
        return rows.filter { r in
            let k = key(kind: r.kind, amount: r.amount, date: r.date, title: r.title, calendar: calendar)
            return seen.insert(k).inserted
        }
    }

    static func incomeSource(_ name: String) -> IncomeSource {
        let n = name.lowercased().trimmingCharacters(in: .whitespaces)
        for source in IncomeSource.allCases {
            let key = ["salary": "Salary", "freelance": "Freelance", "family": "Family", "other": "Other"][source.rawValue] ?? ""
            if L10n.supported.contains(where: { L10n.t(key, language: $0).lowercased() == n }) { return source }
        }
        return .other
    }

    /// Adds the new rows; categories are matched by name (any language), or created. Returns how many were added.
    @MainActor
    @discardableResult
    static func apply(_ rows: [Row], in context: ModelContext) -> Int {
        let entries = (try? context.fetch(FetchDescriptor<Entry>())) ?? []
        let existing = Set(entries.map { key(kind: $0.kind, amount: $0.amount, date: $0.date, title: $0.displayTitle) })
        let fresh = newRows(rows, existing: existing)
        var categories = ((try? context.fetch(FetchDescriptor<BudgetCategory>())) ?? []).filter { !$0.isArchived }
        var order = (categories.map(\.order).max() ?? 0) + 1
        func names(_ c: BudgetCategory) -> [String] {
            var all = [c.name.lowercased(), c.displayName.lowercased()]
            if let t = DefaultCategories.template(for: c.key) {
                all += L10n.supported.map { L10n.t(t.englishName, language: $0).lowercased() }
            }
            return all
        }
        for r in fresh {
            var category: BudgetCategory?
            if r.kind == .expense {
                let name = r.category.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    category = categories.first { names($0).contains(name.lowercased()) }
                    if category == nil {
                        let c = BudgetCategory(name: name, symbol: "tag", order: order)
                        order += 1
                        context.insert(c)
                        categories.append(c)
                        category = c
                    }
                }
            }
            let entry = Entry(kind: r.kind, amount: r.amount, date: r.date, merchant: r.title, note: r.note,
                              category: category, incomeSource: r.kind == .income ? incomeSource(r.category) : .other)
            context.insert(entry)
        }
        try? context.save()
        return fresh.count
    }
}
