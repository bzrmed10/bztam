import Foundation
import Testing
@testable import Bztam

struct OnboardingSetupTests {
    private let cal = Calendar(identifier: .gregorian)
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))! }

    @Test func billDateInsideThePeriod() {
        // Payday 25: period 25 Oct – 24 Nov.
        let period = BudgetCalculator.period(containing: date(2026, 11, 21), payday: 25, calendar: cal)
        let rent = BillCatalog.dateInPeriod(day: 1, period: period, calendar: cal)
        #expect(cal.component(.month, from: rent) == 11 && cal.component(.day, from: rent) == 1)
        let late = BillCatalog.dateInPeriod(day: 28, period: period, calendar: cal)
        #expect(cal.component(.month, from: late) == 10 && cal.component(.day, from: late) == 28)
    }

    @Test func passedBillsStartNowOrNextMonth() {
        let now = date(2026, 11, 21)
        let period = BudgetCalculator.period(containing: now, payday: 1, calendar: cal)
        var bill = BillCatalog.Bill(kindID: "rent", amount: 300_000, day: 5, sameEveryMonth: true, paidThisMonth: true)
        #expect(BillCatalog.hasPassed(day: 5, period: period, now: now, calendar: cal))
        #expect(cal.component(.month, from: BillCatalog.startDate(for: bill, period: period, now: now, calendar: cal)) == 11)
        bill.paidThisMonth = false
        let next = BillCatalog.startDate(for: bill, period: period, now: now, calendar: cal)
        #expect(cal.component(.month, from: next) == 12 && cal.component(.day, from: next) == 5)
        // Still to come this month.
        let phone = BillCatalog.Bill(kindID: "phone", amount: 20_000, day: 25, sameEveryMonth: true, paidThisMonth: false)
        let d = BillCatalog.startDate(for: phone, period: period, now: now, calendar: cal)
        #expect(cal.component(.month, from: d) == 11 && cal.component(.day, from: d) == 25)
    }

    @Test func billsShareCategories() {
        let bills = [BillCatalog.Bill(kindID: "housingLoan", amount: 250_000, day: 1, sameEveryMonth: true),
                     BillCatalog.Bill(kindID: "loan", amount: 80_000, day: 1, sameEveryMonth: true),
                     BillCatalog.Bill(kindID: "utilities", amount: 0, day: 1, sameEveryMonth: false)]
        #expect(BillCatalog.fixedByCategory(bills) == ["loans": 330_000])
        let custom = BillCatalog.Bill(kindID: "", customName: "Parking", amount: 30_000, day: 1, sameEveryMonth: true)
        #expect(custom.categoryKey.hasPrefix("custom-"))
        #expect(BillCatalog.kinds.allSatisfy { DefaultCategories.template(for: $0.categoryKey) != nil })
    }
}
