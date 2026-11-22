import Foundation
import Testing
@testable import Bztam

struct BackupImportTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    private var rows: [ExportRow] {
        [ExportRow(date: date(2026, 11, 3), kind: .expense, amount: 24_550, category: "Groceries", title: "Marjane", note: ""),
         ExportRow(date: date(2026, 11, 1), kind: .income, amount: 800_000, category: "Salary", title: "Salary", note: ""),
         ExportRow(date: date(2026, 11, 5), kind: .expense, amount: 3_800, category: "Café & Food", title: "Café, Maarif", note: "with \"Sara\"")]
    }

    @Test(arguments: ["en", "fr", "ar"])
    func roundTrip(language: String) throws {
        let csv = ExportBuilder.csv(rows, language: language, currency: "MAD", calendar: cal)
        let preview = try BackupImport.preview(csv, calendar: cal)
        #expect(preview.unreadable == 0)
        #expect(preview.rows.count == 3)
        let first = preview.rows.first { $0.title == "Marjane" }
        #expect(first?.amount == 24_550 && first?.kind == .expense)
        let salary = preview.rows.first { $0.kind == .income }
        #expect(salary?.amount == 800_000)
        let cafe = preview.rows.first { $0.amount == 3_800 }
        #expect(cafe?.title == "Café, Maarif")
        #expect(cafe?.note == "with \"Sara\"")
    }

    @Test func skipsWhatIsAlreadyThere() throws {
        let preview = try BackupImport.preview(ExportBuilder.csv(rows, language: "en", currency: "MAD", calendar: cal), calendar: cal)
        let existing: Set<String> = [BackupImport.key(kind: .expense, amount: 24_550, date: date(2026, 11, 3), title: "marjane", calendar: cal)]
        #expect(BackupImport.newRows(preview.rows, existing: existing, calendar: cal).count == 2)
        // The same file twice: the second copy is all duplicates.
        #expect(BackupImport.newRows(preview.rows + preview.rows, existing: [], calendar: cal).count == 3)
    }

    @Test func rejectsOtherFiles() {
        #expect(throws: BackupImport.Failure.notBztam) { try BackupImport.preview("name,email\nSara,s@x.ma\n") }
        #expect(BackupImport.amount("-3000.00") == -300_000)
        #expect(BackupImport.amount("245,50") == 24_550)
        #expect(BackupImport.incomeSource("Salaire") == .salary)
    }
}
