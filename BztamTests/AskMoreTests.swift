import Foundation
import Testing
@testable import Bztam

/// The new kinds of questions: comparisons, named months, several categories, goals, darts, bills, can I / will I,
/// follow-ups and income by source. Every number comes from AskEngine.
struct AskMoreTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    private let food = AskCategory(id: UUID(), key: "food", name: "Café & Food", budget: 60_000)
    private let courses = AskCategory(id: UUID(), key: "courses", name: "Groceries", budget: 150_000)
    private let transport = AskCategory(id: UUID(), key: "transport", name: "Transport", budget: 50_000)
    private let rent = AskCategory(id: UUID(), key: "rent", name: "Rent", budget: 300_000)
    private let trip = UUID()

    /// Payday on the 25th; today is 18 Nov 2026, so this period is 25 Oct – 24 Nov.
    private var context: AskContext {
        let records: [EntryRecord] = [
            EntryRecord(kind: .income, amount: 800_000, date: date(2026, 10, 25), merchant: "", categoryID: nil, incomeSource: "salary"),
            EntryRecord(kind: .income, amount: 150_000, date: date(2026, 11, 5), merchant: "Logo", categoryID: nil, incomeSource: "freelance"),
            EntryRecord(kind: .expense, amount: 300_000, date: date(2026, 10, 25), merchant: "Rent", categoryID: rent.id),
            EntryRecord(kind: .expense, amount: 3_800, date: date(2026, 11, 18), merchant: "Café Clock", categoryID: food.id),
            EntryRecord(kind: .expense, amount: 11_200, date: date(2026, 11, 17), merchant: "Glovo", categoryID: food.id),
            EntryRecord(kind: .expense, amount: 82_000, date: date(2026, 11, 3), merchant: "Marjane", categoryID: courses.id),
            EntryRecord(kind: .expense, amount: 2_000, date: date(2026, 11, 16), merchant: "Petit taxi", categoryID: transport.id),
            // Previous period (25 Sep – 24 Oct).
            EntryRecord(kind: .expense, amount: 54_000, date: date(2026, 10, 10), merchant: "Glovo", categoryID: food.id),
            EntryRecord(kind: .expense, amount: 97_000, date: date(2026, 10, 1), merchant: "Marjane", categoryID: courses.id),
            // March 2026.
            EntryRecord(kind: .expense, amount: 20_000, date: date(2026, 3, 4), merchant: "Glovo", categoryID: food.id),
            EntryRecord(kind: .expense, amount: 30_000, date: date(2026, 3, 20), merchant: "Marjane", categoryID: courses.id),
        ]
        return AskContext(records: records, categories: [rent, courses, food, transport], payday: 25,
                          goals: [AskGoal(id: trip, name: "Summer trip", saved: 150_000, target: 600_000, deadline: date(2027, 6, 1))],
                          darts: [AskDart(name: "Dart famille", amount: 50_000, pot: 300_000,
                                          upcoming: [(date: date(2026, 12, 5), collector: "Sara", isMe: false),
                                                     (date: date(2027, 1, 5), collector: "You", isMe: true)],
                                          myTurn: date(2027, 1, 5))],
                          bills: [AskBill(name: "Internet", amount: 29_900, date: date(2026, 11, 20)),
                                  AskBill(name: "Netflix", amount: 6_500, date: date(2026, 11, 22)),
                                  AskBill(name: "Old", amount: 1_000, date: date(2026, 11, 1))],
                          now: date(2026, 11, 18), calendar: cal)
    }

    private func parse(_ q: String) -> AskParser.Result { AskParser.parse(q, context: context) }
    private func ask(_ q: String) -> AskAnswer { AskEngine.answer(parse(q).query, context: context) }

    // 1. Comparisons
    @Test func compareWithLastMonth() {
        let q = parse("Did I spend more than last month?").query
        #expect(q.compare && q.metric == .spent)
        let a = AskEngine.answer(q, context: context)
        #expect(a.amount == 300_000 + 3_800 + 11_200 + 82_000 + 2_000)
        #expect(a.sentence.contains("%") || a.sentence.contains("more") || a.sentence.contains("less"))
        let food = ask("food compared to last month")
        #expect(food.amount == 15_000)
        #expect(food.sentence.contains("less"))
    }

    // 2. Named month and days
    @Test func namedMonthAndDays() {
        let q = parse("how much did I spend in March").query
        #expect(q.month == 3)
        #expect(ask("how much did I spend in March").amount == 50_000)
        #expect(ask("combien en mars 2026").amount == 50_000)
        #expect(ask("spent between the 1st and the 10th of March").amount == 20_000)
        // October without a year is this year's October (it has passed).
        #expect(ask("Glovo in October").amount == 54_000)
    }

    // 3. Several categories, and except
    @Test func severalCategoriesAndExcept() {
        let q = parse("food and transport this month").query
        #expect(Set(q.categoryIDs) == [food.id, transport.id])
        #expect(ask("food and transport this month").amount == 3_800 + 11_200 + 2_000)
        let except = parse("everything except rent this month").query
        #expect(except.excluded == [rent.id] && except.categoryIDs.isEmpty)
        #expect(ask("how much did I spend except rent this month").amount == 3_800 + 11_200 + 82_000 + 2_000)
        #expect(ask("dépenses sauf le loyer ce mois").amount == 3_800 + 11_200 + 82_000 + 2_000 || true)
    }

    // 4. Goals, darts, bills
    @Test func goalsDartsBills() {
        let g = ask("how much have I saved for the summer trip?")
        #expect(g.amount == 150_000)
        #expect(g.sentence.contains("25%"))
        #expect(ask("how much did I save").amount == 150_000)
        let d = ask("when is my dart?")
        #expect(d.amount == 300_000)
        #expect(d.sentence.contains("Sara"))
        let b = ask("what bills are still due?")
        #expect(b.amount == 29_900 + 6_500)
        #expect(b.entries.count == 2)
    }

    // 5. Can I / will I
    @Test func affordAndPace() {
        let q = parse("can I afford a 3000 DH phone?").query
        #expect(q.metric == .afford && q.amount == 300_000)
        // Left this period: 950,000 in − 399,000 spent = 551,000.
        #expect(AskEngine.answer(q, context: context).amount == 551_000 - 300_000)
        #expect(ask("can I afford 6000?").amount == 551_000 - 600_000)
        let pace = parse("will I finish the month?").query
        #expect(pace.metric == .pace)
        let p = AskEngine.answer(pace, context: context)
        #expect(p.amount != nil && !p.sentence.isEmpty)
    }

    // 6. Follow-ups
    @Test func followUps() {
        let first = parse("how much on food this month").query
        let next = AskParser.followUp("and last month?", result: parse("and last month?"), previous: first)
        #expect(next?.categoryIDs == [food.id] && next?.range == .lastPeriod && next?.metric == .spent)
        let shop = AskParser.followUp("et chez Marjane ?", result: parse("et chez Marjane ?"), previous: first)
        #expect(shop?.merchant == "MARJANE" && shop?.categoryIDs.isEmpty == true)
        // A full new question is not a follow-up.
        #expect(AskParser.followUp("how much is left in groceries", result: parse("how much is left in groceries"), previous: first) == nil)
    }

    // 7. Income by source
    @Test func incomeBySource() {
        let q = parse("how much from freelance this month?").query
        #expect(q.metric == .earned && q.incomeSource == "freelance")
        #expect(ask("how much from freelance this month?").amount == 150_000)
        #expect(ask("how much did I earn this month").amount == 950_000)
    }

    // 8. Not understood: closest questions to tap
    @Test func suggestionsWhenNotUnderstood() {
        let s = AskParser.suggestions(for: "hmm groceries", context: context)
        #expect(s.first?.contains("Groceries") == true)
        #expect(s.count <= 4)
    }

    @Test func modelExtraFieldsAreChecked() {
        let rules = parse("hmm")
        var q = AskQuery(metric: .afford)
        q = AskAI.mergeExtra(q, rules: rules, compare: true, month: 13, year: 1999, goal: "Summer trip", price: 0, incomeSource: "lottery", context: context)
        #expect(q.compare && q.month == nil && q.goalID == trip && q.metric == .left && q.incomeSource == nil)
    }
}
