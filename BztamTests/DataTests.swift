import Foundation
import PDFKit
import SwiftData
import Testing
@testable import Bztam

struct ExportTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    private var rows: [ExportRow] {
        [
            ExportRow(date: date(2026, 11, 3), kind: .expense, amount: 24_550, category: "Courses", title: "Marjane", note: ""),
            ExportRow(date: date(2026, 10, 25), kind: .income, amount: 800_000, category: "Salaire", title: "Salaire", note: ""),
            ExportRow(date: date(2026, 11, 5), kind: .expense, amount: 3_800, category: "Café & Food", title: "Café \"Clock\"", note: "with Sara, Omar"),
        ]
    }

    @Test func decimals() {
        #expect(ExportBuilder.decimal(24_550, comma: false) == "245.50")
        #expect(ExportBuilder.decimal(-300_000, comma: true) == "-3000,00")
        #expect(ExportBuilder.decimal(5, comma: false) == "0.05")
    }

    @Test func englishCSV() {
        let csv = ExportBuilder.csv(rows, language: "en", currency: "MAD", calendar: cal)
        #expect(csv.hasPrefix("\u{FEFF}Date,Type,Amount,Currency,Category,Shop or note,Note\r\n"))
        let lines = csv.dropFirst().components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 4)
        // Oldest first, expenses negative, quotes doubled, commas quoted.
        #expect(lines[1] == "2026-10-25,Money in,8000.00,MAD,Salaire,Salaire,")
        #expect(lines[2] == "2026-11-03,Expense,-245.50,MAD,Courses,Marjane,")
        #expect(lines[3] == "2026-11-05,Expense,-38.00,MAD,Café & Food,\"Café \"\"Clock\"\"\",\"with Sara, Omar\"")
    }

    @Test func frenchCSVUsesSemicolonsAndCommas() {
        let csv = ExportBuilder.csv(rows, language: "fr", currency: "MAD", calendar: cal)
        let lines = csv.dropFirst().components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines[0].components(separatedBy: ";").count == 7)
        #expect(lines[2].contains(";-245,50;MAD;"))
        // A comma inside a field is fine with ";" columns: no quotes needed.
        #expect(lines[3].hasSuffix(";with Sara, Omar"))
    }

    @Test func filenames() {
        let p = BudgetPeriod(start: date(2026, 10, 25), end: date(2026, 11, 25))
        #expect(ExportBuilder.filename(.thisPeriod, period: p, ext: "csv", calendar: cal) == "Bztam 2026-10-25 – 2026-11-24.csv")
    }

    @MainActor @Test func pdfHasPages() {
        let many = (0..<120).map { i in
            ExportRow(date: date(2026, 11, 1 + i % 20), kind: .expense, amount: 1_000 + i, category: "Other", title: "Shop \(i)", note: "")
        }
        let data = ExportPDF.make(subtitle: "25 Oct – 24 Nov", moneyIn: 800_000, spent: 524_000,
                                  categories: [.init(name: "Courses", spent: 85_000, budget: 120_000)], rows: many)
        let doc = PDFDocument(data: data)
        #expect((doc?.pageCount ?? 0) >= 3)
        #expect(doc?.string?.contains("Shop 119") == true)
    }
}

@MainActor
struct CloudMergeTests {
    @Test func keepsOneSettingsAndOneCategoryPerKey() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext

        let old = AppSettings(payday: 25, onboardingDone: true, expectedIncome: 800_000)
        let fresh = AppSettings(payday: 1, onboardingDone: false)
        context.insert(old)
        context.insert(fresh)

        let a = BudgetCategory(key: "food", name: "Food", symbol: "cup.and.saucer", budget: 60_000, order: 5)
        let b = BudgetCategory(key: "food", name: "Food", symbol: "cup.and.saucer", budget: 40_000, order: 5)
        let custom1 = BudgetCategory(name: "Kids", symbol: "star")
        let custom2 = BudgetCategory(name: "Kids", symbol: "star")
        for c in [a, b, custom1, custom2] { context.insert(c) }
        let e1 = Entry(kind: .expense, amount: 100, category: a)
        let e2 = Entry(kind: .expense, amount: 200, category: b)
        let e3 = Entry(kind: .expense, amount: 300, category: b)
        for e in [e1, e2, e3] { context.insert(e) }

        // The same recurring entry added on two iPhones.
        let rule = UUID()
        let r1 = Entry(kind: .expense, amount: 300_000, date: .now, merchant: "Rent", source: .recurring)
        let r2 = Entry(kind: .expense, amount: 300_000, date: .now, merchant: "Rent", source: .recurring)
        r1.recurringID = rule
        r2.recurringID = rule
        context.insert(r1)
        context.insert(r2)
        try context.save()

        let removed = CloudSync.mergeDuplicates(in: context)
        #expect(removed == 3)

        let settings = try context.fetch(FetchDescriptor<AppSettings>())
        #expect(settings.count == 1 && settings.first?.payday == 25)

        let food = try context.fetch(FetchDescriptor<BudgetCategory>()).filter { $0.key == "food" }
        #expect(food.count == 1)
        // The one with more entries is kept, and every entry now points at it.
        #expect(food.first?.budget == 40_000)
        #expect(food.first?.entries?.count == 3)
        // Custom categories have no key: they are never merged.
        #expect(try context.fetch(FetchDescriptor<BudgetCategory>()).filter { $0.name == "Kids" }.count == 2)
        #expect(try context.fetch(FetchDescriptor<Entry>()).filter { $0.recurringID == rule }.count == 1)

        #expect(CloudSync.mergeDuplicates(in: context) == 0)
    }
}
