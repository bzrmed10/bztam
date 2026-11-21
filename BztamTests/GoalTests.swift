import Foundation
import Testing
@testable import Bztam

struct GoalTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    @Test func savedAddsAndTakesOut() {
        let a = UUID(), b = UUID()
        let moves = [GoalMoveValue(goalID: a, amount: 50_000, date: date(2026, 11, 2)),
                     GoalMoveValue(goalID: a, amount: -20_000, date: date(2026, 11, 10)),
                     GoalMoveValue(goalID: b, amount: 10_000, date: date(2026, 10, 30))]
        #expect(GoalMath.saved(a, in: moves) == 30_000)
        #expect(GoalMath.saved(b, in: moves) == 10_000)
        let period = BudgetCalculator.period(containing: date(2026, 11, 5), payday: 1, calendar: cal)
        #expect(GoalMath.saved(in: period, moves: moves) == 30_000)
        #expect(GoalMath.saved(a, in: period, moves: moves) == 30_000)
    }

    @Test func monthlySuggestion() {
        // 6,000 DH by mid-July 2027, from 21 Nov 2026: Nov…Jun = 8 months → 750 DH.
        let s = GoalMath.suggestedMonthly(target: 600_000, saved: 0, deadline: date(2027, 7, 15), now: date(2026, 11, 21), calendar: cal)
        #expect(s == 75_000)
        // Rounded up to 10 DH.
        let r = GoalMath.suggestedMonthly(target: 100_000, saved: 0, deadline: date(2027, 2, 1), now: date(2026, 11, 21), calendar: cal)
        #expect(r == 34_000)
        #expect(GoalMath.suggestedMonthly(target: 100_000, saved: 100_000, deadline: date(2027, 2, 1), now: date(2026, 11, 21), calendar: cal) == 0)
        #expect(GoalMath.suggestedMonthly(target: 100_000, saved: 0, deadline: nil) == 0)
    }

    @Test func progress() {
        #expect(GoalMath.progress(saved: 150_000, target: 600_000) == 0.25)
        #expect(GoalMath.progress(saved: 700_000, target: 600_000) == 1)
        #expect(GoalMath.progress(saved: 100, target: 0) == 0)
    }

    @Test func savingLowersWhatIsLeft() {
        let period = BudgetCalculator.period(containing: date(2026, 11, 5), payday: 1, calendar: cal)
        let entries = [EntryValue(kind: .income, amount: 800_000, date: date(2026, 11, 1), categoryID: nil),
                       EntryValue(kind: .expense, amount: 300_000, date: date(2026, 11, 3), categoryID: nil)]
        let s = BudgetCalculator.summary(entries: entries, categories: [], period: period, saved: 50_000)
        #expect(s.spent == 300_000)
        #expect(s.saved == 50_000)
        #expect(s.left == 450_000)
    }
}
