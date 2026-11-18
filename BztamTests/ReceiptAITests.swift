import Foundation
import Testing
@testable import Bztam

/// The model itself only runs on Apple Intelligence iPhones; these tests check the safety net around it.
struct ReceiptAITests {
    private let lines = ["Boulangerie Al Amal", "Pain 4,00", "Msemen 6,00", "Payé 10,00", "Merci"]

    @Test func acceptsValuesFoundInTheText() {
        let draft = ReceiptDraft(amount: nil, date: nil, merchant: nil, categoryKey: nil, confidence: .none)
        let merged = ReceiptAI.merge(draft, fields: ("10,00", "Boulangerie Al Amal", "", "food"), lines: lines)
        #expect(merged.amount == 1_000)
        #expect(merged.confidence == .high)
        #expect(merged.merchant == "Boulangerie Al Amal")
        #expect(merged.categoryKey == "food")
    }

    @Test func rejectsInventedValues() {
        let draft = ReceiptDraft(amount: nil, date: nil, merchant: nil, categoryKey: nil, confidence: .none)
        let merged = ReceiptAI.merge(draft, fields: ("99,00", "Starbucks", "not a date", "shopping"), lines: lines)
        #expect(merged.amount == nil)
        #expect(merged.merchant == nil)
        #expect(merged.date == nil)
        #expect(merged.categoryKey == nil)
    }

    @Test func neverOverridesAConfidentTotal() {
        let draft = ReceiptDraft(amount: 1_000, date: nil, merchant: "X", categoryKey: "food", confidence: .high)
        let merged = ReceiptAI.merge(draft, fields: ("6,00", "Other", "", "courses"), lines: lines)
        #expect(merged.amount == 1_000)
        #expect(merged.merchant == "X")
        #expect(merged.categoryKey == "food")
    }
}
