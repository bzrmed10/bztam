import Foundation
import Testing
@testable import Bztam

struct AdviceTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: 12))! }
    private var period: BudgetPeriod { BudgetCalculator.period(containing: date(11, 10), payday: 1, calendar: cal) }

    @Test func fastSpendingRunsOutEarly() {
        let c = CategoryValue(id: UUID(), budget: 60_000, isFixed: false)
        // 300 DH in the first 10 days → 30 DH/day → 600 DH gone on day 20.
        let e = [EntryValue(kind: .expense, amount: 30_000, date: date(11, 5), categoryID: c.id)]
        let w = Advice.paceWarnings(categories: [c], entries: e, period: period, now: date(11, 10), calendar: cal)
        #expect(w.count == 1)
        #expect(cal.component(.day, from: w[0].runOut) == 21)
    }

    @Test func slowSpendingIsFine() {
        let c = CategoryValue(id: UUID(), budget: 60_000, isFixed: false)
        let e = [EntryValue(kind: .expense, amount: 18_000, date: date(11, 5), categoryID: c.id)]
        #expect(Advice.paceWarnings(categories: [c], entries: e, period: period, now: date(11, 10), calendar: cal).isEmpty)
    }

    @Test func tooEarlyFixedOrUsedUpGiveNoWarning() {
        let c = CategoryValue(id: UUID(), budget: 60_000, isFixed: false)
        let fixed = CategoryValue(id: UUID(), budget: 60_000, isFixed: true)
        let e = [EntryValue(kind: .expense, amount: 50_000, date: date(11, 1), categoryID: c.id),
                 EntryValue(kind: .expense, amount: 50_000, date: date(11, 1), categoryID: fixed.id)]
        #expect(Advice.paceWarnings(categories: [c, fixed], entries: e, period: period, now: date(11, 2), calendar: cal).isEmpty)
        let used = [EntryValue(kind: .expense, amount: 60_000, date: date(11, 3), categoryID: c.id)]
        #expect(Advice.paceWarnings(categories: [c], entries: used, period: period, now: date(11, 10), calendar: cal).isEmpty)
    }

    @Test func weekendShare() {
        let id = UUID()
        // 14 Nov 2026 is a Saturday, 16 Nov a Monday.
        let e = [EntryValue(kind: .expense, amount: 300, date: date(11, 14), categoryID: id),
                 EntryValue(kind: .expense, amount: 100, date: date(11, 16), categoryID: id)]
        #expect(Advice.weekendShare(categoryID: id, entries: e, period: period, calendar: cal) == 0.75)
    }

    @Test func suggestionsFromTwoPreviousMonths() {
        let food = CategoryValue(id: UUID(), budget: 60_000, isFixed: false)
        let rent = CategoryValue(id: UUID(), budget: 300_000, isFixed: true)
        let gifts = CategoryValue(id: UUID(), budget: 0, isFixed: false)
        let e = [
            EntryValue(kind: .expense, amount: 80_000, date: date(10, 5), categoryID: food.id),
            EntryValue(kind: .expense, amount: 92_000, date: date(9, 5), categoryID: food.id),
            EntryValue(kind: .expense, amount: 300_000, date: date(10, 1), categoryID: rent.id),
            EntryValue(kind: .expense, amount: 300_000, date: date(9, 1), categoryID: rent.id),
            EntryValue(kind: .expense, amount: 20_000, date: date(9, 20), categoryID: gifts.id)
        ]
        let s = Advice.budgetSuggestions(categories: [food, rent, gifts], entries: e, current: period, payday: 1, calendar: cal)
        #expect(s.contains(BudgetSuggestion(categoryID: food.id, amount: 90_000)), "average 860 DH rounded up to 900")
        #expect(!s.contains { $0.categoryID == rent.id }, "rent matches its budget")
        #expect(s.contains(BudgetSuggestion(categoryID: gifts.id, amount: 10_000)))
    }

    @Test func noSuggestionsWithOnlyOneMonth() {
        let food = CategoryValue(id: UUID(), budget: 60_000, isFixed: false)
        let e = [EntryValue(kind: .expense, amount: 90_000, date: date(10, 5), categoryID: food.id)]
        #expect(Advice.budgetSuggestions(categories: [food], entries: e, current: period, payday: 1, calendar: cal).isEmpty)
    }

    @Test func daysLeft() {
        #expect(Advice.daysLeft(in: period, now: date(11, 25), calendar: cal) == 6)
    }
}
