import Foundation
import Testing
@testable import Bztam

struct RecurringTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 9))! }
    private func day(_ d: Date) -> [Int] { let c = cal.dateComponents([.month, .day], from: d); return [c.month!, c.day!] }

    @Test func monthlyKeepsTheEndOfTheMonth() {
        let d = RecurringEngine.occurrences(frequency: .monthly, start: date(2027, 1, 31), after: nil, through: date(2027, 4, 30), calendar: cal)
        #expect(d.map(day) == [[1, 31], [2, 28], [3, 31], [4, 30]])
    }

    @Test func onlyNewOccurrencesAfterTheLastOne() {
        let d = RecurringEngine.occurrences(frequency: .monthly, start: date(2026, 1, 25), after: date(2026, 10, 25),
                                            through: date(2026, 12, 1), calendar: cal)
        #expect(d.map(day) == [[11, 25]])
    }

    @Test func weeklyAndYearly() {
        let w = RecurringEngine.occurrences(frequency: .weekly, start: date(2026, 11, 2), after: nil, through: date(2026, 11, 20), calendar: cal)
        #expect(w.map(day) == [[11, 2], [11, 9], [11, 16]])
        let y = RecurringEngine.occurrences(frequency: .yearly, start: date(2024, 2, 29), after: nil, through: date(2026, 3, 1), calendar: cal)
        #expect(y.map(day) == [[2, 29], [2, 28], [2, 28]])
    }

    @Test func nothingBeforeTheStart() {
        #expect(RecurringEngine.occurrences(frequency: .monthly, start: date(2026, 12, 1), after: nil, through: date(2026, 11, 30), calendar: cal).isEmpty)
    }

    // MARK: Subscriptions

    private func netflix(_ m: Int, _ amount: Centimes = 6_500) -> EntryRecord {
        EntryRecord(kind: .expense, amount: amount, date: date(2026, m, 5), merchant: "Netflix", categoryID: nil)
    }

    @Test func detectsAMonthlySubscription() {
        let records = [netflix(8), netflix(9), netflix(10), netflix(11)]
        let c = SubscriptionDetector.candidates(records, excluding: [], now: date(2026, 11, 18), calendar: cal)
        #expect(c.count == 1)
        #expect(c.first?.merchant == "Netflix")
        #expect(c.first?.amount == 6_500)
    }

    @Test func ignoresIrregularOrExcludedOrOld() {
        let now = date(2026, 11, 18)
        #expect(SubscriptionDetector.candidates([netflix(9), netflix(11)], excluding: [], now: now, calendar: cal).isEmpty)
        #expect(SubscriptionDetector.candidates([netflix(9), netflix(10), netflix(11, 20_000)], excluding: [], now: now, calendar: cal).isEmpty)
        #expect(SubscriptionDetector.candidates([netflix(9), netflix(10), netflix(11)], excluding: ["NETFLIX"], now: now, calendar: cal).isEmpty)
        #expect(SubscriptionDetector.candidates([netflix(5), netflix(6), netflix(7)], excluding: [], now: now, calendar: cal).isEmpty)
    }

    @Test func frequentShopsAreNotSubscriptions() {
        let now = date(2026, 11, 18)
        var records: [EntryRecord] = []
        for m in 9...11 { for d in [3, 10, 17] { records.append(EntryRecord(kind: .expense, amount: 2_000, date: date(2026, m, d), merchant: "Petit taxi", categoryID: nil)) } }
        #expect(SubscriptionDetector.candidates(records, excluding: [], now: now, calendar: cal).isEmpty)
    }
}
