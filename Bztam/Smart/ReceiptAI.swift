import Foundation
import FoundationModels

/// Fields Apple's on-device model fills from receipt text.
@Generable
struct AIReceiptFields {
    @Guide(description: "The total amount paid, written as on the receipt, for example 245,50. Empty if there is none.")
    var total: String
    @Guide(description: "The shop or company name. Empty if there is none.")
    var merchant: String
    @Guide(description: "The date of the receipt as DD/MM/YYYY. Empty if there is none.")
    var date: String
    @Guide(description: "One of: courses, food, transport, bills, phone, rent, goingout, other.")
    var category: String
}

/// Uses Apple Intelligence (on device, free, private) to fill what the rules missed.
/// The model only reads; every value it returns is checked against the receipt text before it is used.
enum ReceiptAI {
    static let categories: Set<String> = ["courses", "food", "transport", "bills", "phone", "rent", "goingout", "other"]

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func improve(_ draft: ReceiptDraft, lines: [String]) async -> ReceiptDraft {
        let complete = draft.confidence == .high && draft.merchant != nil && draft.date != nil && draft.categoryKey != nil
        guard !complete, isAvailable, !lines.isEmpty else { return draft }
        guard let fields = await ask(lines: Array(lines.prefix(80))) else { return draft }
        return merge(draft, fields: (fields.total, fields.merchant, fields.date, fields.category), lines: lines)
    }

    private static func ask(lines: [String]) async -> AIReceiptFields? {
        let session = LanguageModelSession(instructions: """
            You read the text of Moroccan receipts and bills, in French or English. \
            Copy values exactly as they appear in the text. Never invent a value: leave it empty instead.
            """)
        let prompt = "Receipt text:\n" + lines.joined(separator: "\n")
        return try? await session.respond(to: prompt, generating: AIReceiptFields.self).content
    }

    /// Keeps only values that can be found in the receipt text. Pure, so it is unit-tested.
    static func merge(_ draft: ReceiptDraft, fields: (total: String, merchant: String, date: String, category: String),
                      lines: [String], now: Date = .now, calendar: Calendar = .current) -> ReceiptDraft {
        var result = draft
        let allAmounts = Set(lines.flatMap { ReceiptParser.amounts(in: $0) })
        if draft.amount == nil || draft.confidence == .low,
           let amount = ReceiptParser.parseAmount(fields.total.filter { $0.isNumber || $0 == "," || $0 == "." || $0 == " " }),
           allAmounts.contains(amount) {
            result.amount = amount
            result.confidence = .high
        }
        let merchant = fields.merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.merchant == nil, merchant.count >= 2,
           lines.contains(where: { ReceiptParser.fold($0).contains(ReceiptParser.fold(merchant)) }) {
            result.merchant = merchant
        }
        if draft.date == nil, let d = ReceiptParser.date(in: [fields.date], now: now, calendar: calendar) {
            result.date = d
        }
        let category = fields.category.lowercased().trimmingCharacters(in: .whitespaces)
        if draft.categoryKey == nil, categories.contains(category) {
            result.categoryKey = category
        }
        return result
    }
}
