import Foundation

/// What to export.
enum ExportRange: String, CaseIterable, Identifiable, Sendable {
    case thisPeriod, lastPeriod, thisYear, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .thisPeriod: L10n.t("This period")
        case .lastPeriod: L10n.t("Last period")
        case .thisYear: L10n.t("This year")
        case .all: L10n.t("Everything")
        }
    }

    func interval(payday: Int, now: Date = .now, calendar: Calendar = .current) -> BudgetPeriod {
        let ctx = AskContext(records: [], categories: [], payday: payday, now: now, calendar: calendar)
        switch self {
        case .thisPeriod: return AskEngine.interval(.thisPeriod, context: ctx)
        case .lastPeriod: return AskEngine.interval(.lastPeriod, context: ctx)
        case .thisYear: return AskEngine.interval(.thisYear, context: ctx)
        case .all: return AskEngine.interval(.all, context: ctx)
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case csv, pdf
    var id: String { rawValue }
    var title: String { self == .csv ? "CSV" : "PDF" }
}

/// One line of the export, as plain values.
struct ExportRow: Sendable, Equatable {
    var date: Date
    var kind: EntryKind
    var amount: Centimes
    var category: String
    var title: String
    var note: String
}

/// CSV text and file names. Pure, unit-tested.
enum ExportBuilder {
    /// French spreadsheets expect ";" between columns and "," for decimals; English ones "," and ".".
    static func csv(_ rows: [ExportRow], language: String, currency: String, calendar: Calendar = .current) -> String {
        let fr = language == "fr"
        let sep = fr ? ";" : ","
        let header = ["Date", "Type", "Amount", "Currency", "Category", "Shop or note", "Note"]
            .map { escape(L10n.t($0, language: language), sep: sep) }
            .joined(separator: sep)
        var lines = [header]
        for r in rows.sorted(by: { $0.date < $1.date }) {
            let signed = r.kind == .expense ? -r.amount : r.amount
            lines.append([
                isoDay(r.date, calendar: calendar),
                L10n.t(r.kind == .expense ? "Expense" : "Money in", language: language),
                decimal(signed, comma: fr),
                currency,
                r.category,
                r.title,
                r.note
            ].map { escape($0, sep: sep) }.joined(separator: sep))
        }
        // The byte order mark makes Excel read accents (é, à) correctly.
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }

    /// 24550 → "245.50" (or "245,50"); -300000 → "-3000.00". No thousands separator, so spreadsheets read it as a number.
    static func decimal(_ centimes: Centimes, comma: Bool) -> String {
        let sign = centimes < 0 ? "-" : ""
        let a = abs(centimes)
        return sign + "\(a / 100)" + (comma ? "," : ".") + String(format: "%02d", a % 100)
    }

    static func escape(_ field: String, sep: String) -> String {
        guard field.contains(sep) || field.contains("\"") || field.contains("\n") || field.contains("\r") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func isoDay(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// "Bztam 2026-10-25 to 2026-11-24.csv", or "Bztam all.csv".
    static func filename(_ range: ExportRange, period: BudgetPeriod, ext: String, calendar: Calendar = .current) -> String {
        if range == .all { return "Bztam \(L10n.t("all")).\(ext)" }
        return "Bztam \(isoDay(period.start, calendar: calendar)) – \(isoDay(period.lastDay(calendar: calendar), calendar: calendar)).\(ext)"
    }
}
