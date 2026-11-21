import Testing
@testable import Bztam

struct BudgetPlannerTests {
    @Test func typicalPlanFitsTheIncome() {
        let a = BudgetPlanner.Answers(income: 800_000, fixed: ["rent": 300_000, "phone": 20_000],
                                      eatingOut: .mid, gettingAround: .mid, saving: .mid)
        let p = BudgetPlanner.plan(a)
        #expect(p.budgets["rent"] == 300_000)
        #expect(p.budgets["phone"] == 20_000)
        #expect(p.budgets["bills"] == nil)
        #expect(p.savings == 80_000)
        let total = p.budgets.values.reduce(0, +)
        #expect(total + p.savings <= 800_000)
        // Everyday categories fit in what is left: 8,000 - 3,200 bills - 800 savings = 4,000.
        #expect(total - 320_000 <= 400_000)
        #expect(p.budgets.values.allSatisfy { $0 % 5_000 == 0 })
    }

    @Test func answersChangeTheSplit() {
        var a = BudgetPlanner.Answers(income: 1_500_000, eatingOut: .low, gettingAround: .low, saving: .low)
        let modest = BudgetPlanner.plan(a)
        a.eatingOut = .high
        a.gettingAround = .high
        let lively = BudgetPlanner.plan(a)
        #expect(lively.budgets["food"]! > modest.budgets["food"]!)
        #expect(lively.budgets["transport"]! > modest.budgets["transport"]!)
        #expect(modest.savings == 0)
    }

    @Test func billsBiggerThanIncome() {
        let a = BudgetPlanner.Answers(income: 300_000, fixed: ["rent": 350_000], saving: .high)
        let p = BudgetPlanner.plan(a)
        #expect(p.savings == 0)
        #expect(p.budgets["courses"] == 0)
    }

    @Test func noIncomeKeepsOnlyBills() {
        let p = BudgetPlanner.plan(.init(income: 0, fixed: ["rent": 200_000]))
        #expect(p.budgets == ["rent": 200_000])
    }

    @Test func rounding() {
        #expect(BudgetPlanner.round50(124_900) == 120_000)
        #expect(BudgetPlanner.round50(-100) == 0)
    }

    @Test func householdRaisesGroceries() {
        var a = BudgetPlanner.Answers(income: 1_000_000, saving: .low)
        let alone = BudgetPlanner.plan(a).budgets["courses"]!
        a.adults = 2; a.children = 2
        let family = BudgetPlanner.plan(a).budgets["courses"]!
        #expect(alone == 120_000)
        #expect(family == 250_000)
        #expect(BudgetPlanner.groceriesPercent(adults: 6, children: 8) == 35)
    }

    @Test func transportPassComesOnTop() {
        let a = BudgetPlanner.Answers(income: 1_000_000, fixed: ["transport": 30_000], gettingAround: .low, saving: .low)
        #expect(BudgetPlanner.plan(a).budgets["transport"] == 30_000 + 30_000)
    }

    @Test func leftoverChoices() {
        let a = BudgetPlanner.Answers(income: 1_000_000, eatingOut: .low, gettingAround: .low, saving: .low)
        let p = BudgetPlanner.plan(a)
        #expect(p.leftover > 0)
        #expect(BudgetPlanner.apply(.buffer, to: p, answers: a) == p)
        let saved = BudgetPlanner.apply(.savings, to: p, answers: a)
        #expect(saved.savings == BudgetPlanner.round50(p.leftover))
        let spread = BudgetPlanner.apply(.spread, to: p, answers: a)
        #expect(spread.budgets["courses"]! > p.budgets["courses"]!)
        #expect(spread.leftover < p.leftover)
        let total = spread.budgets.values.reduce(0, +) + spread.savings + spread.leftover
        #expect(total == 1_000_000)
    }
}
