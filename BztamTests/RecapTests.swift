import Foundation
import Testing
@testable import Bztam

struct RecapTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
    private let food = UUID(), courses = UUID(), bills = UUID()
    private func e(_ amount: Centimes, _ d: Date, _ c: UUID, _ m: String = "") -> EntryRecord {
        EntryRecord(kind: .expense, amount: amount, date: d, merchant: m, categoryID: c)
    }

    @Test func lastWeekAgainstUsual() {
        // Today Wed 18 Nov 2026; last week is Mon 9 – Sun 15 Nov.
        var records = [e(30_000, date(2026, 11, 10), food), e(50_000, date(2026, 11, 14), courses),
                       e(9_999, date(2026, 11, 16), food)] // this week: not counted
        for k in 1...4 {
            records.append(e(100_000, cal.date(byAdding: .day, value: -7 * k, to: date(2026, 11, 11))!, courses))
        }
        let r = WeeklyRecap.lastWeek(records, now: date(2026, 11, 18), calendar: cal)
        #expect(r?.spent == 80_000)
        #expect(r?.usual == 100_000)
        #expect(r?.change == -20)
        #expect(r?.topCategoryID == courses)
        #expect(cal.component(.day, from: r!.weekStart) == 9)
    }

    @Test func noRecapWithoutLastWeek() {
        #expect(WeeklyRecap.lastWeek([e(100, date(2026, 11, 17), food)], now: date(2026, 11, 18), calendar: cal) == nil)
        let r = WeeklyRecap.lastWeek([e(100, date(2026, 11, 12), food)], now: date(2026, 11, 18), calendar: cal)
        #expect(r?.usual == nil && r?.change == nil)
    }

    @Test func billMuchHigherThanUsual() {
        let period = BudgetCalculator.period(containing: date(2026, 11, 18), payday: 1, calendar: cal)
        let records = [e(30_000, date(2026, 8, 5), bills, "Lydec"), e(31_000, date(2026, 9, 5), bills, "Lydec"),
                       e(29_000, date(2026, 10, 5), bills, "Lydec"), e(45_000, date(2026, 11, 5), bills, "LYDEC")]
        let found = UnusualSpending.billAlerts(records, period: period, calendar: cal)
        #expect(found.count == 1)
        #expect(found.first?.kind == .bill(merchant: "LYDEC"))
        #expect(found.first?.percent == 50)
        // A normal bill raises nothing.
        let normal = Array(records.dropLast()) + [e(32_000, date(2026, 11, 5), bills, "Lydec")]
        #expect(UnusualSpending.billAlerts(normal, period: period, calendar: cal).isEmpty)
    }

    @Test func categoryAheadOfUsual() {
        // Payday the 1st, today the 18th: compare 1–18 Nov with 1–18 of Aug, Sep, Oct.
        var records: [EntryRecord] = []
        for m in 8...10 { records.append(e(40_000, date(2026, m, 10), food)); records.append(e(40_000, date(2026, m, 25), food)) }
        records.append(e(70_000, date(2026, 11, 12), food))
        let period = BudgetCalculator.period(containing: date(2026, 11, 18), payday: 1, calendar: cal)
        let found = UnusualSpending.detect(records, period: period, payday: 1, now: date(2026, 11, 18), calendar: cal)
        #expect(found.first?.kind == .category(food))
        #expect(found.first?.usual == 40_000)
        #expect(found.first?.percent == 75)
        // Early in the period, no category alerts (too little to compare).
        #expect(UnusualSpending.detect(records, period: period, payday: 1, now: date(2026, 11, 3), calendar: cal).isEmpty)
    }
}
