import Testing
@testable import Bztam

struct BudgetAlertsTests {
    @Test func crossingEightyPercent() {
        #expect(BudgetAlerts.crossed(before: 70_000, after: 85_000, budget: 100_000) == [80])
    }

    @Test func crossingBothAtOnce() {
        #expect(BudgetAlerts.crossed(before: 10_000, after: 120_000, budget: 100_000) == [80, 100])
    }

    @Test func exactlyAtTheThreshold() {
        #expect(BudgetAlerts.crossed(before: 79_999, after: 80_000, budget: 100_000) == [80])
        #expect(BudgetAlerts.crossed(before: 99_000, after: 100_000, budget: 100_000) == [100])
    }

    @Test func alreadyPastOrNoBudget() {
        #expect(BudgetAlerts.crossed(before: 85_000, after: 90_000, budget: 100_000).isEmpty)
        #expect(BudgetAlerts.crossed(before: 0, after: 90_000, budget: 0).isEmpty)
        #expect(BudgetAlerts.crossed(before: 90_000, after: 80_000, budget: 100_000).isEmpty)
    }
}
