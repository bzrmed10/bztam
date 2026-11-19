import Foundation
import FoundationModels

/// What Apple's on-device model fills from a question. It never sees amounts and never answers:
/// it only says what is being asked, and code computes the answer.
@Generable
struct AIAskFields {
    @Guide(description: "true if the question is about the user's money, spending, income or budget; false otherwise.")
    var isAboutMoney: Bool
    @Guide(description: "One of: spent (total spent), earned (money received), left (what's left to spend), count (how many expenses or times), biggest (largest single expense), top (category where most money went), owed (who owes the user or whom the user owes, from split bills).")
    var metric: String
    @Guide(description: "One of: thisPeriod (this month, the default), lastPeriod (last month), thisWeek, lastWeek, today, yesterday, thisYear, all (since the start).")
    var range: String
    @Guide(description: "A category key from the list, or empty if the question names no category.")
    var category: String
    @Guide(description: "A shop name from the list, copied exactly, or empty if the question names no shop.")
    var shop: String
}

enum AskAI {
    static var isAvailable: Bool { ReceiptAI.isAvailable }

    /// Rules first; the model only fills what the rules did not find. Returns nil when Ask should show examples.
    static func understand(_ question: String, context: AskContext) async -> AskQuery? {
        let rules = AskParser.parse(question, context: context)
        let complete = rules.foundMetric && rules.foundRange && (rules.query.categoryID != nil || rules.query.merchant != nil)
        guard !complete, isAvailable, let fields = await ask(question, context: context) else {
            return rules.aboutMoney ? rules.query : nil
        }
        return merge(rules, fields: (fields.isAboutMoney, fields.metric, fields.range, fields.category, fields.shop), context: context)
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
