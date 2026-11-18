import Foundation
import Testing
@testable import Bztam

struct SmartHelpersTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ d: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h))! }

    // MARK: Category memory

    @Test func memoryUsesTheLatestChoiceForTheSameShop() {
        let food = UUID(), courses = UUID()
        let records = [
            EntryRecord(kind: .expense, amount: 100, date: date(1), merchant: "Café Clock", categoryID: courses),
            EntryRecord(kind: .expense, amount: 100, date: date(5), merchant: "CAFE CLOCK!", categoryID: food),
            EntryRecord(kind: .expense, amount: 100, date: date(6), merchant: "Marjane", categoryID: courses)
        ]
        #expect(CategoryMemory.category(for: "cafe clock", in: records) == food)
        #expect(CategoryMemory.category(for: "Glovo", in: records) == nil)
        #expect(CategoryMemory.category(for: "", in: records) == nil)
    }

    // MARK: Duplicates

    @Test func duplicateSameAmountShopAndDay() {
        let records = [EntryRecord(kind: .expense, amount: 24_550, date: date(17, 9), merchant: "Marjane", categoryID: nil)]
        #expect(DuplicateCheck.find(amount: 24_550, date: date(17, 20), merchant: "MARJANE", in: records, calendar: cal) != nil)
        #expect(DuplicateCheck.find(amount: 24_550, date: date(18), merchant: "", in: records, calendar: cal) != nil)
    }

    @Test func notADuplicate() {
        let records = [EntryRecord(kind: .expense, amount: 24_550, date: date(17), merchant: "Marjane", categoryID: nil)]
        #expect(DuplicateCheck.find(amount: 24_500, date: date(17), merchant: "Marjane", in: records, calendar: cal) == nil)
        #expect(DuplicateCheck.find(amount: 24_550, date: date(10), merchant: "Marjane", in: records, calendar: cal) == nil)
        #expect(DuplicateCheck.find(amount: 24_550, date: date(17), merchant: "Carrefour", in: records, calendar: cal) == nil)
    }

    // MARK: Type it

    @Test func taxi() {
        let q = QuickEntryParser.parse("taxi 20")
        #expect(q.amount == 2_000)
        #expect(q.categoryKey == "transport")
        #expect(q.text == "Taxi")
        #expect(q.kind == .expense)
    }

    @Test func cafeWithAccent() {
        let q = QuickEntryParser.parse("café 38")
        #expect(q.amount == 3_800)
        #expect(q.categoryKey == "food")
        #expect(q.text == "Café")
    }

    @Test func darija() {
        let q = QuickEntryParser.parse("khlst 50 f l9hwa")
        #expect(q.amount == 5_000)
        #expect(q.categoryKey == "food")
        #expect(q.text == "L9hwa")
    }

    @Test func knownShopWithDecimals() {
        let q = QuickEntryParser.parse("Glovo 112,50")
        #expect(q.amount == 11_250)
        #expect(q.categoryKey == "food")
        #expect(q.text == "Glovo")
    }

    @Test func siriStyle() {
        let q = QuickEntryParser.parse("zid 20 dh hanout")
        #expect(q.amount == 2_000)
        #expect(q.categoryKey == "courses")
        #expect(q.text == "Hanout")
    }

    @Test func income() {
        let q = QuickEntryParser.parse("+8000 salaire")
        #expect(q.kind == .income)
        #expect(q.amount == 800_000)
        #expect(q.incomeSource == .salary)
        #expect(q.categoryKey == nil)
    }

    @Test func noAmount() {
        let q = QuickEntryParser.parse("lunch with Sara")
        #expect(q.amount == nil)
        #expect(q.categoryKey == "food")
        #expect(q.text == "Lunch with Sara")
    }
}
