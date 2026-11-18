import Foundation
import Testing
@testable import Bztam

struct BudgetCalculatorTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Africa/Casablanca")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func periodStartsOnPaydayInTheSameMonth() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 17), payday: 1, calendar: cal)
        #expect(p.start == cal.startOfDay(for: date(2026, 11, 1)))
        #expect(p.end == cal.startOfDay(for: date(2026, 12, 1)))
    }

    @Test func beforePaydayBelongsToThePreviousMonth() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 17), payday: 25, calendar: cal)
        #expect(p.start == cal.startOfDay(for: date(2026, 10, 25)))
        #expect(p.end == cal.startOfDay(for: date(2026, 11, 25)))
        #expect(cal.component(.day, from: p.lastDay(calendar: cal)) == 24)
    }

    @Test func januaryBeforePaydayGoesBackToDecember() {
        let p = BudgetCalculator.period(containing: date(2027, 1, 10), payday: 25, calendar: cal)
        #expect(p.start == cal.startOfDay(for: date(2026, 12, 25)))
    }

    @Test func paydayIsInsideItsOwnPeriod() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 25, 0), payday: 25, calendar: cal)
        #expect(p.start == cal.startOfDay(for: date(2026, 11, 25)))
    }

    @Test func paydayAbove28IsClamped() {
        let p = BudgetCalculator.period(containing: date(2027, 2, 28), payday: 31, calendar: cal)
        #expect(p.start == cal.startOfDay(for: date(2027, 2, 28)))
    }

    @Test func offsetMovesWholePeriods() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 17), payday: 25, calendar: cal)
        let prev = BudgetCalculator.period(p, offset: -1, payday: 25, calendar: cal)
        #expect(prev.start == cal.startOfDay(for: date(2026, 9, 25)))
        #expect(prev.end == p.start)
    }

    // The design numbers: 8,000 in, 5,240 spent, 2,760 left, 6,500 planned, 1,500 not planned.
    private let rent = CategoryValue(id: UUID(), budget: 300_000, isFixed: true)
    private let courses = CategoryValue(id: UUID(), budget: 120_000, isFixed: false)
    private let food = CategoryValue(id: UUID(), budget: 60_000, isFixed: false)
    private let others = CategoryValue(id: UUID(), budget: 170_000, isFixed: false)

    private func designEntries() -> [EntryValue] {
        [
            EntryValue(kind: .income, amount: 800_000, date: date(2026, 10, 25), categoryID: nil),
            EntryValue(kind: .expense, amount: 300_000, date: date(2026, 10, 25), categoryID: rent.id),
            EntryValue(kind: .expense, amount: 85_000, date: date(2026, 11, 10), categoryID: courses.id),
            EntryValue(kind: .expense, amount: 64_000, date: date(2026, 11, 12), categoryID: food.id),
            EntryValue(kind: .expense, amount: 75_000, date: date(2026, 11, 14), categoryID: others.id),
            // Outside the period: ignored.
            EntryValue(kind: .expense, amount: 99_900, date: date(2026, 10, 24), categoryID: courses.id),
            EntryValue(kind: .income, amount: 100_000, date: date(2026, 11, 25), categoryID: nil)
        ]
    }

    @Test func summaryMatchesTheDesign() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 17), payday: 25, calendar: cal)
        let s = BudgetCalculator.summary(entries: designEntries(), categories: [rent, courses, food, others], period: p)
        #expect(s.moneyIn == 800_000)
        #expect(s.spent == 524_000)
        #expect(s.left == 276_000)
        #expect(s.planned == 650_000)
        #expect(s.notPlanned == 150_000)
        #expect(abs(s.progress - 0.655) < 0.001)
    }

    @Test func notPlannedUsesExpectedIncomeBeforeMoneyArrives() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 17), payday: 25, calendar: cal)
        let s = BudgetCalculator.summary(entries: [], categories: [rent], period: p, expectedIncome: 500_000)
        #expect(s.moneyIn == 0)
        #expect(s.notPlanned == 200_000)
    }

    @Test func categoryStates() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 17), payday: 25, calendar: cal)
        let entries = designEntries()
        #expect(BudgetCalculator.status(for: rent, entries: entries, period: p).state == .paid)
        #expect(BudgetCalculator.status(for: courses, entries: entries, period: p).state == .left(35_000))
        #expect(BudgetCalculator.status(for: food, entries: entries, period: p).state == .over(4_000))
        let none = CategoryValue(id: UUID(), budget: 0, isFixed: false)
        #expect(BudgetCalculator.status(for: none, entries: entries, period: p).state == .noBudget)
    }

    @Test func variableCategoryFullySpentShowsZeroLeft() {
        let p = BudgetCalculator.period(containing: date(2026, 11, 17), payday: 25, calendar: cal)
        let c = CategoryValue(id: UUID(), budget: 10_000, isFixed: false)
        let e = [EntryValue(kind: .expense, amount: 10_000, date: date(2026, 11, 1), categoryID: c.id)]
        #expect(BudgetCalculator.status(for: c, entries: e, period: p).state == .left(0))
    }

    @Test func progressIsClamped() {
        let s = CategoryStatus(budget: 100, spent: 250, state: .over(150))
        #expect(s.progress == 1)
    }
}
