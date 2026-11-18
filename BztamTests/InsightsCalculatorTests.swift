import Foundation
import Testing
@testable import Bztam

struct InsightsCalculatorTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: 12))! }
    private var period: BudgetPeriod { BudgetCalculator.period(containing: date(11, 17), payday: 25, calendar: cal) }
    private var previous: BudgetPeriod { BudgetCalculator.period(period, offset: -1, payday: 25, calendar: cal) }

    private let food = UUID(), courses = UUID(), rent = UUID()

    private var entries: [EntryValue] {
        [
            EntryValue(kind: .expense, amount: 300_000, date: date(10, 25), categoryID: rent),
            EntryValue(kind: .expense, amount: 64_000, date: date(11, 2), categoryID: food),
            EntryValue(kind: .expense, amount: 85_000, date: date(11, 3), categoryID: courses),
            EntryValue(kind: .expense, amount: 1_000, date: date(11, 4), categoryID: nil),
            EntryValue(kind: .income, amount: 800_000, date: date(10, 25), categoryID: nil),
            // Previous period
            EntryValue(kind: .expense, amount: 300_000, date: date(9, 26), categoryID: rent),
            EntryValue(kind: .expense, amount: 54_000, date: date(10, 1), categoryID: food),
            EntryValue(kind: .expense, amount: 97_000, date: date(10, 2), categoryID: courses)
        ]
    }

    @Test func spendIsGroupedAndSorted() {
        let s = InsightsCalculator.spendByCategory(entries, period: period)
        #expect(s.map(\.amount) == [300_000, 85_000, 64_000, 1_000])
        #expect(s.first?.categoryID == rent)
    }

    @Test func smallSlicesFoldIntoOther() {
        let spends = (1...8).map { CategorySpend(categoryID: UUID(), amount: $0 * 100) }.reversed()
        let top = InsightsCalculator.topSlices(Array(spends), limit: 4)
        #expect(top.count == 4)
        #expect(top.last?.categoryID == nil)
        #expect(top.last?.amount == 500 + 400 + 300 + 200 + 100)
    }

    @Test func changeRatio() {
        #expect(InsightsCalculator.change(current: 90, previous: 100) == -0.1)
        #expect(InsightsCalculator.change(current: 10, previous: 0) == nil)
    }

    @Test func biggestChanges() {
        let now = InsightsCalculator.spendByCategory(entries, period: period)
        let before = InsightsCalculator.spendByCategory(entries, period: previous)
        let changes = InsightsCalculator.biggestChanges(current: now, previous: before)
        #expect(changes.count == 2, "rent did not change, uncategorized is skipped")
        #expect(changes.first?.categoryID == food)
        #expect(abs((changes.first?.ratio ?? 0) - 0.185) < 0.001)
        #expect(changes.last?.categoryID == courses)
    }
}
