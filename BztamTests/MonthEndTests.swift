import Foundation
import Testing
@testable import Bztam

struct MonthEndTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))! }
    private var october: BudgetPeriod { BudgetCalculator.period(containing: date(2026, 11, 1), payday: 25, calendar: cal) }
    private var november: BudgetPeriod { BudgetCalculator.period(containing: date(2026, 11, 26), payday: 25, calendar: cal) }

    private func close(_ choice: MonthEndChoice, amount: Centimes, moved: Centimes, decided: Date = .distantPast) -> MonthCloseValue {
        MonthCloseValue(periodStart: october.start, periodEnd: october.end, amount: amount, moved: moved, choice: choice, decidedAt: decided)
    }

    @Test func carryingMovesMoneyFromOneMonthToTheNext() {
        let entries = [
            EntryValue(kind: .income, amount: 800_000, date: date(2026, 10, 25), categoryID: nil),
            EntryValue(kind: .expense, amount: 736_000, date: date(2026, 11, 2), categoryID: nil),
            EntryValue(kind: .income, amount: 800_000, date: date(2026, 11, 25), categoryID: nil)
        ]
        let closes = [close(.nextMonth, amount: 64_000, moved: 64_000)]
        let before = BudgetCalculator.summary(entries: entries, categories: [], period: october,
                                              carriedIn: MonthEndMath.carriedIn(october, closes: closes),
                                              carriedOut: MonthEndMath.carriedOut(october, closes: closes))
        let after = BudgetCalculator.summary(entries: entries, categories: [], period: november,
                                             carriedIn: MonthEndMath.carriedIn(november, closes: closes),
                                             carriedOut: MonthEndMath.carriedOut(november, closes: closes))
        #expect(before.left == 0)
        #expect(after.carriedIn == 64_000)
        #expect(after.left == 864_000)
    }

    @Test func overspendTakenFromNextMonth() {
        let closes = [close(.nextMonth, amount: -30_000, moved: -30_000)]
        #expect(MonthEndMath.carriedIn(november, closes: closes) == -30_000)
        #expect(MonthEndMath.carriedOut(october, closes: closes) == -30_000)
        #expect(MonthEndMath.carriedIn(october, closes: closes) == 0)
    }

    @Test func latestDecisionWins() {
        let closes = [close(.nextMonth, amount: 64_000, moved: 64_000, decided: date(2026, 11, 25, 10)),
                      close(.leave, amount: 64_000, moved: 0, decided: date(2026, 11, 25, 11))]
        #expect(MonthEndMath.latest(closes).count == 1)
        #expect(MonthEndMath.carriedIn(november, closes: closes) == 0)
    }

    @Test func pendingRules() {
        let summary = PeriodSummary(moneyIn: 800_000, spent: 736_000, planned: 0, notPlanned: 0)
        let now = date(2026, 11, 26)
        let early = date(2026, 9, 1)
        #expect(MonthEndMath.pending(previous: october, current: november, previousSummary: summary, closes: [],
                                     firstUse: early, now: now, calendar: cal) == 64_000)
        // Already decided.
        #expect(MonthEndMath.pending(previous: october, current: november, previousSummary: summary,
                                     closes: [close(.leave, amount: 64_000, moved: 0)], firstUse: early, now: now, calendar: cal) == nil)
        // Started using the app after that month ended.
        #expect(MonthEndMath.pending(previous: october, current: november, previousSummary: summary, closes: [],
                                     firstUse: date(2026, 11, 25, 15), now: now, calendar: cal) == nil)
        // Started halfway through that month: still asked.
        #expect(MonthEndMath.pending(previous: october, current: november, previousSummary: summary, closes: [],
                                     firstUse: date(2026, 11, 10), now: now, calendar: cal) == 64_000)
        // No money in that month: nothing to say.
        #expect(MonthEndMath.pending(previous: october, current: november,
                                     previousSummary: PeriodSummary(moneyIn: 0, spent: 50_000, planned: 0, notPlanned: 0),
                                     closes: [], firstUse: early, now: now, calendar: cal) == nil)
        // Too late in the new month.
        #expect(MonthEndMath.pending(previous: october, current: november, previousSummary: summary, closes: [],
                                     firstUse: early, now: date(2026, 12, 10), calendar: cal) == nil)
        // Over budget.
        #expect(MonthEndMath.pending(previous: october, current: november,
                                     previousSummary: PeriodSummary(moneyIn: 800_000, spent: 830_000, planned: 0, notPlanned: 0),
                                     closes: [], firstUse: early, now: now, calendar: cal) == -30_000)
    }

    @Test func historyShowsTheAmountBeforeTheDecision() {
        let entries = [
            EntryValue(kind: .income, amount: 800_000, date: date(2026, 10, 25), categoryID: nil),
            EntryValue(kind: .expense, amount: 736_000, date: date(2026, 11, 2), categoryID: nil),
            EntryValue(kind: .income, amount: 800_000, date: date(2026, 9, 25), categoryID: nil),
            EntryValue(kind: .expense, amount: 830_000, date: date(2026, 10, 2), categoryID: nil)
        ]
        let goal = UUID()
        let moves = [GoalMoveValue(goalID: goal, amount: 64_000, date: october.end.addingTimeInterval(-1))]
        var c = close(.goal, amount: 64_000, moved: 64_000)
        c.goalID = goal
        let past = MonthEndMath.history(entries: entries, moves: moves, closes: [c], current: november, payday: 25, calendar: cal)
        #expect(past.count == 2)
        #expect(past[0].left == 64_000)
        #expect(past[0].close?.goalID == goal)
        #expect(past[1].left == -30_000)
        #expect(past[1].close == nil)
    }
}
