import Foundation
import FoundationModels

/// What Apple's on-device model fills from a question. It never sees amounts and never answers:
/// it only says what is being asked, and code computes the answer.
@Generable
struct AIAskFields {
    @Guide(description: "true if the question is about the user's money, spending, income or budget; false otherwise.")
    var isAboutMoney: Bool
    @Guide(description: "One of: spent (total spent), earned (money received), left (what's left to spend), count (how many expenses or times), biggest (largest single expense), top (category where most money went), owed (who owes the user or whom the user owes, from split bills), goal (money saved for a savings goal), dart (a dart or tontine: next round, whose turn), bills (recurring bills still to pay), afford (can the user afford a price), pace (will the money last until payday).")
    var metric: String
    @Guide(description: "One of: thisPeriod (this month, the default), lastPeriod (last month), thisWeek, lastWeek, today, yesterday, thisYear, all (since the start).")
    var range: String
    @Guide(description: "A category key from the list, or empty if the question names no category.")
    var category: String
    @Guide(description: "A shop name from the list, copied exactly, or empty if the question names no shop.")
    var shop: String
    @Guide(description: "true if the question compares two periods (more or less than before); false otherwise.")
    var compare: Bool
    @Guide(description: "The month named in the question, 1 to 12, or 0 if none.")
    var month: Int
    @Guide(description: "The year named in the question, like 2026, or 0 if none.")
    var year: Int
    @Guide(description: "A savings goal name from the list, copied exactly, or empty.")
    var goal: String
    @Guide(description: "For afford questions, the price in whole units of money, or 0.")
    var price: Int
    @Guide(description: "For money received: salary, freelance, family, or empty.")
    var incomeSource: String
}

enum AskAI {
    static var isAvailable: Bool { ReceiptAI.isAvailable }

    /// Rules first; the model only fills what the rules did not find. Returns nil when Ask should show examples.
    /// `previous` is the last question, for follow-ups ("and last month?").
    static func understand(_ question: String, context: AskContext, previous: AskQuery? = nil) async -> AskQuery? {
        let rules = AskParser.parse(question, context: context)
        if let follow = AskParser.followUp(question, result: rules, previous: previous) { return follow }
        let complete = rules.foundMetric && rules.foundRange && (!rules.query.categoryIDs.isEmpty || rules.query.merchant != nil)
        guard !complete, isAvailable, let fields = await ask(question, context: context) else {
            return rules.aboutMoney ? rules.query : nil
        }
        guard var q = merge(rules, fields: (fields.isAboutMoney, fields.metric, fields.range, fields.category, fields.shop), context: context)
        else { return nil }
        q = mergeExtra(q, rules: rules, compare: fields.compare, month: fields.month, year: fields.year, goal: fields.goal,
                       price: fields.price, incomeSource: fields.incomeSource, context: context)
        return q
    }

    /// The new fields: only valid values, and never over what the rules found. Pure, unit-tested.
    static func mergeExtra(_ q: AskQuery, rules: AskParser.Result, compare: Bool, month: Int, year: Int, goal: String,
                           price: Int, incomeSource: String, context: AskContext) -> AskQuery {
        var q = q
        if compare { q.compare = true }
        if q.month == nil, (1...12).contains(month) {
            q.month = month
            if (2000...2100).contains(year) { q.year = year }
        }
        if q.goalID == nil, let g = context.goals.first(where: { CategoryMemory.key($0.name) == CategoryMemory.key(goal) && !goal.isEmpty }) {
            q.goalID = g.id
        }
        if q.metric == .afford, q.amount == nil, price > 0 { q.amount = price * 100 }
        if q.metric == .afford, q.amount == nil { q.metric = .left }
        if q.metric == .earned, q.incomeSource == nil, IncomeSource(rawValue: incomeSource) != nil { q.incomeSource = incomeSource }
        return q
    }

    private static func ask(_ question: String, context: AskContext) async -> AIAskFields? {
        let categories = context.categories.map { "\($0.key): \($0.name)" }.joined(separator: "\n")
        let shops = context.merchants.prefix(60).map(\.name).joined(separator: ", ")
        let session = LanguageModelSession(instructions: """
            You read questions people ask about their own spending in a budget app, in French, English or Moroccan Darija \
            written in Latin letters. You only classify the question; you never answer it.
            Categories (key: name):
            \(categories)
            Shops the user has paid: \(shops)
            Savings goals: \(context.goals.map(\.name).joined(separator: ", "))
            """)
        return try? await session.respond(to: "Question: " + question, generating: AIAskFields.self).content
    }

    /// Keeps the rules' findings and takes from the model only valid values for what is missing. Pure, unit-tested.
    static func merge(_ rules: AskParser.Result,
                      fields: (aboutMoney: Bool, metric: String, range: String, category: String, shop: String),
                      context: AskContext) -> AskQuery? {
        guard rules.aboutMoney || fields.aboutMoney else { return nil }
        var q = rules.query
        if !rules.foundMetric, let m = AskQuery.Metric(rawValue: fields.metric.trimmingCharacters(in: .whitespaces)) { q.metric = m }
        if !rules.foundRange, let r = AskQuery.Range(rawValue: fields.range.trimmingCharacters(in: .whitespaces)) { q.range = r }
        if q.categoryID == nil, q.merchant == nil {
            let key = fields.category.lowercased().trimmingCharacters(in: .whitespaces)
            let shop = CategoryMemory.key(fields.shop)
            if let c = context.categories.first(where: { $0.key == key }) {
                q.categoryID = c.id
            } else if shop.count >= 3, context.merchants.contains(where: { $0.key == shop }) {
                q.merchant = shop
            }
        }
        return q
    }
}
