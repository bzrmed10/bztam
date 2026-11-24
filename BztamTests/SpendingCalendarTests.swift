import Foundation
import Testing
@testable import Bztam

struct SpendingCalendarTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2  // Monday
        return c
    }
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))! }

    @Test func dailyTotalsCountRefundsBack() {
        let entries = [
            EntryValue(kind: .expense, amount: 28_000, date: date(2026, 11, 22, 13), categoryID: nil),
            EntryValue(kind: .expense, amount: -7_000, date: date(2026, 11, 22, 20), categoryID: nil),
            EntryValue(kind: .expense, amount: 6_000, date: date(2026, 11, 22, 9), categoryID: nil),
            EntryValue(kind: .income, amount: 800_000, date: date(2026, 11, 22), categoryID: nil),
            EntryValue(kind: .expense, amount: 5_000, date: date(2026, 10, 31), categoryID: nil)
        ]
        let daily = SpendingCalendar.daily(entries, month: date(2026, 11, 5), calendar: cal)
        #expect(daily[cal.startOfDay(for: date(2026, 11, 22))] == 27_000)
        #expect(daily.count == 1)
    }

    @Test func wholeRounding() {
        #expect(SpendingCalendar.whole(30_350) == 30_400)
        #expect(SpendingCalendar.whole(10_791) == 10_800)
        #expect(SpendingCalendar.whole(15_449) == 15_400)
    }

    @Test func levels() {
        #expect(SpendingCalendar.level(0, average: 20_000) == 0)
        #expect(SpendingCalendar.level(5_000, average: 20_000) == 1)
        #expect(SpendingCalendar.level(20_000, average: 20_000) == 2)
        #expect(SpendingCalendar.level(50_000, average: 20_000) == 3)
    }

    @Test func monthGridStartsOnTheRightWeekday() {
        // 1 November 2026 is a Sunday: six blanks before it when weeks start on Monday.
        let cells = SpendingCalendar.cells(month: date(2026, 11, 10), calendar: cal)
        #expect(cells.prefix(6).allSatisfy { $0 == nil })
        #expect(cells[6].map { cal.component(.day, from: $0) } == 1)
        #expect(cells.compactMap { $0 }.count == 30)
    }
}
