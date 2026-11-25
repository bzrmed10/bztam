import Foundation
import Testing
@testable import Bztam

struct AskTests {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }

    private let food = AskCategory(id: UUID(), key: "food", name: "Café & Food", budget: 60_000)
    private let courses = AskCategory(id: UUID(), key: "courses", name: "Groceries", budget: 150_000)
    private let transport = AskCategory(id: UUID(), key: "transport", name: "Transport", budget: 0)
    private let rent = AskCategory(id: UUID(), key: "rent", name: "Rent", budget: 300_000)

    /// Payday on the 25th; today is 18 Nov 2026, so this period is 25 Oct – 24 Nov.
    private var context: AskContext {
        let records: [EntryRecord] = [
            EntryRecord(kind: .income, amount: 800_000, date: date(2026, 10, 25), merchant: "", categoryID: nil),
            EntryRecord(kind: .expense, amount: 300_000, date: date(2026, 10, 25), merchant: "Rent", categoryID: rent.id),
            EntryRecord(kind: .expense, amount: 3_800, date: date(2026, 11, 18), merchant: "Café Clock", categoryID: food.id),
            EntryRecord(kind: .expense, amount: 11_200, date: date(2026, 11, 17), merchant: "Glovo", categoryID: food.id),
            EntryRecord(kind: .expense, amount: 82_000, date: date(2026, 11, 3), merchant: "Marjane", categoryID: courses.id),
            EntryRecord(kind: .expense, amount: 45_000, date: date(2026, 10, 28), merchant: "Marjane", categoryID: courses.id),
            EntryRecord(kind: .expense, amount: 2_000, date: date(2026, 11, 16), merchant: "Taxi", categoryID: transport.id),
            // Previous period (25 Sep – 24 Oct).
            EntryRecord(kind: .expense, amount: 54_000, date: date(2026, 10, 10), merchant: "Glovo", categoryID: food.id),
            EntryRecord(kind: .expense, amount: 97_000, date: date(2026, 10, 1), merchant: "Marjane", categoryID: courses.id),
        ]
        return AskContext(records: records, categories: [rent, courses, food, transport], payday: 25, now: date(2026, 11, 18), calendar: cal)
    }

    private func parse(_ q: String) -> AskParser.Result { AskParser.parse(q, context: context) }
    private func ask(_ q: String) -> AskAnswer { AskEngine.answer(parse(q).query, context: context) }

    // MARK: Understanding

    @Test func englishFrenchAndDarija() {
        let en = parse("How much did I spend on coffee last month?").query
        #expect(en == AskQuery(metric: .spent, range: .lastPeriod, categoryIDs: [food.id]))
        let fr = parse("Combien il me reste pour les courses ?").query
        #expect(fr == AskQuery(metric: .left, range: .thisPeriod, categoryIDs: [courses.id]))
        let darija = parse("ch7al sreft f taxi had simana").query
        #expect(darija.metric == .spent && darija.range == .thisWeek)
        #expect(darija.merchant == "TAXI")
    }

    @Test func ownCategoryNameBeatsShopAndKeyword() {
        // "Rent" is both a category name and a shop the user typed; the category wins.
        #expect(parse("rent this year").query.categoryID == rent.id)
        // "Marjane" is a known shop: answer for the shop, not all groceries.
        let q = parse("How many times did I go to Marjane?").query
        #expect(q.metric == .count && q.merchant == "MARJANE" && q.categoryID == nil)
    }

    @Test func lastWeekIsNotLastMonth() {
        #expect(parse("dépenses de la semaine dernière").query.range == .lastWeek)
        #expect(parse("mois dernier").query.range == .lastPeriod)
        #expect(parse("aujourd'hui").query.range == .today)
    }

    @Test func notAboutMoneyShowsExamples() {
        #expect(!parse("tell me a joke").aboutMoney)
        #expect(parse("combien ?").aboutMoney)
    }

    // MARK: Answers (numbers come from code only)

    @Test func spentOnACategoryThisAndLastPeriod() {
        #expect(ask("how much on food this month").amount == 15_000)
        #expect(ask("how much on food last month").amount == 54_000)
        #expect(ask("how much did I spend").amount == 300_000 + 3_800 + 11_200 + 82_000 + 45_000 + 2_000)
    }

    @Test func spentAtAShop() {
        let a = ask("how much at Marjane since I started")
        #expect(a.amount == 82_000 + 45_000 + 97_000)
        #expect(a.entries.count == 3)
        #expect(a.entries.first?.amount == 82_000)
    }

    @Test func leftOverallAndInACategory() {
        #expect(ask("how much is left").amount == 800_000 - 444_000)
        #expect(ask("what's left in groceries").amount == 150_000 - 127_000)
        // No budget: no amount, but still an answer.
        let t = ask("how much left for transport")
        #expect(t.amount == nil && !t.sentence.isEmpty)
    }

    @Test func earnedCountBiggestTop() {
        #expect(ask("how much money in this month").amount == 800_000)
        let count = ask("how many times at Glovo since the start")
        #expect(count.amount == nil && count.entries.count == 2)
        #expect(ask("biggest expense this month").amount == 300_000)
        #expect(ask("biggest expense in groceries this month").amount == 82_000)
        let top = ask("where did my money go last month")
        #expect(top.amount == 97_000)
    }

    @Test func weekAndDayRanges() {
        // Week of Mon 16 Nov – Sun 22 Nov.
        #expect(ask("spent this week").amount == 3_800 + 11_200 + 2_000)
        #expect(ask("spent yesterday").amount == 11_200)
        #expect(ask("spent today").amount == 3_800)
    }

    @Test func nothingFound() {
        let a = ask("how much on transport last month")
        #expect(a.amount == nil && a.entries.isEmpty && !a.sentence.isEmpty)
    }

    // MARK: Model merge

    @Test func modelOnlyFillsWhatRulesMissed() {
        let rules = parse("le resto la semaine passée")
        // Rules found the range; the model's range is ignored, its valid metric and category are used.
        let q = AskAI.merge(rules, fields: (true, "spent", "thisYear", "food", ""), context: context)
        #expect(q?.range == .lastWeek)
        #expect(q?.categoryID == food.id)
    }

    @Test func modelValuesAreChecked() {
        let rules = parse("hmm")
        let q = AskAI.merge(rules, fields: (true, "average", "nextYear", "pets", "Amazon"), context: context)
        #expect(q == AskQuery())
        #expect(AskAI.merge(rules, fields: (false, "spent", "today", "", ""), context: context) == nil)
        let shop = AskAI.merge(rules, fields: (true, "count", "all", "", "glovo"), context: context)
        #expect(shop?.merchant == "GLOVO" && shop?.metric == .count)
    }
}
