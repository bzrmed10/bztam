import Foundation
import Testing
@testable import Bztam

struct ReceiptParserTests {
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Africa/Casablanca")!
        return c
    }
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 18))! }

    private func day(_ d: Date?) -> [Int]? {
        guard let d else { return nil }
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return [c.year!, c.month!, c.day!]
    }

    @Test func amountFormats() {
        #expect(ReceiptParser.parseAmount("245,50") == 24_550)
        #expect(ReceiptParser.parseAmount("245.50") == 24_550)
        #expect(ReceiptParser.parseAmount("245,5") == 24_550)
        #expect(ReceiptParser.parseAmount("1 234,56") == 123_456)
        #expect(ReceiptParser.parseAmount("1.234,56") == 123_456)
        #expect(ReceiptParser.parseAmount("1,234.56") == 123_456)
        #expect(ReceiptParser.parseAmount("1.234") == 123_400)
        #expect(ReceiptParser.parseAmount("38") == 3_800)
        #expect(ReceiptParser.parseAmount("0") == nil)
    }

    @Test func amountsSkipDatesAndTimes() {
        #expect(ReceiptParser.amounts(in: "17/11/2026 18:42 CAISSE 3") == [300])
        #expect(ReceiptParser.amounts(in: "TOTAL TTC 245,50 DH") == [24_550])
    }

    @Test func marjaneReceipt() {
        let lines = [
            "MARJANE", "Casablanca Ain Sebaa", "Tel 0522 00 00 00", "17/11/2026 18:42",
            "LAIT 1L x2 15,80", "PAIN COMPLET 12,00", "HUILE OLIVE 89,90", "TOMATES 2KG 18,00",
            "SOUS-TOTAL 204,58", "TVA 20% 40,92", "TOTAL TTC 245,50", "ESPECES 300,00", "RENDU 54,50", "MERCI DE VOTRE VISITE"
        ]
        let d = ReceiptParser.parse(lines: lines, now: now, calendar: cal)
        #expect(d.amount == 24_550)
        #expect(d.confidence == .high)
        #expect(d.merchant == "Marjane")
        #expect(d.categoryKey == "courses")
        #expect(day(d.date) == [2026, 11, 17])
        #expect(d.looksLikeBill)
    }

    @Test func totalOnTheNextLine() {
        let lines = ["CARREFOUR MARKET", "NET A PAYER", "1 318,00 DH", "18-11-2026"]
        let d = ReceiptParser.parse(lines: lines, now: now, calendar: cal)
        #expect(d.amount == 131_800)
        #expect(d.merchant == "Carrefour Market")
        #expect(day(d.date) == [2026, 11, 18])
    }

    @Test func strongKeywordBeatsPlainTotal() {
        let lines = ["CAFE CLOCK", "TOTAL 3", "Montant à payer : 38,00 MAD"]
        let d = ReceiptParser.parse(lines: lines, now: now, calendar: cal)
        #expect(d.amount == 3_800)
        #expect(d.categoryKey == "food")
    }

    @Test func inwiBillScreenshot() {
        let lines = [
            "inwi", "Ma facture", "Facture du 05 nov. 2026", "Forfait Internet 50Go", "Montant total", "200,00 DH", "Payer ma facture"
        ]
        let d = ReceiptParser.parse(lines: lines, now: now, calendar: cal)
        #expect(d.amount == 20_000)
        #expect(d.merchant == "Inwi")
        #expect(d.categoryKey == "phone")
        #expect(day(d.date) == [2026, 11, 5])
    }

    @Test func glovoOrderInEnglish() {
        let lines = ["Glovo", "Your order from Pizza Place", "Subtotal 98.00 MAD", "Delivery 14.00 MAD", "Total 112.00 MAD"]
        let d = ReceiptParser.parse(lines: lines, now: now, calendar: cal)
        #expect(d.amount == 11_200)
        #expect(d.merchant == "Glovo")
        #expect(d.categoryKey == "food")
    }

    @Test func fallbackUsesCurrencyMarkedAmounts() {
        let lines = ["Station Afriquia", "Gasoil 40,5 L", "450,00 DH"]
        let d = ReceiptParser.parse(lines: lines, now: now, calendar: cal)
        #expect(d.amount == 45_000)
        #expect(d.confidence == .low)
        #expect(!d.looksLikeBill)
        #expect(d.categoryKey == "transport")
    }

    @Test func nothingFound() {
        let d = ReceiptParser.parse(lines: ["Hello", "a photo of a cat"], now: now, calendar: cal)
        #expect(d.amount == nil)
        #expect(d.confidence == .none)
    }

    @Test func unknownShopUsesFirstMeaningfulLine() {
        let lines = ["TICKET N° 0042", "boulangerie al amal", "Total 24,00"]
        let d = ReceiptParser.parse(lines: lines, now: now, calendar: cal)
        #expect(d.merchant == "Boulangerie Al Amal")
        #expect(d.categoryKey == "food")
        #expect(d.amount == 2_400)
    }

    @Test func futureAndAncientDatesAreIgnored() {
        #expect(ReceiptParser.date(in: ["01/01/2031"], now: now, calendar: cal) == nil)
        #expect(ReceiptParser.date(in: ["01/01/2019"], now: now, calendar: cal) == nil)
        #expect(day(ReceiptParser.date(in: ["2026-10-30"], now: now, calendar: cal)) == [2026, 10, 30])
    }

    @Test func shortWordsMatchWholeWordsOnly() {
        #expect(MerchantDirectory.match(in: ["BIMO SNACK"])?.name != "BIM")
        #expect(MerchantDirectory.match(in: ["BIM Maarif"])?.name == "BIM")
    }

    @Test func linesAreGroupedLeftToRight() {
        // Vision gives "TOTAL TTC" and "245,50" as two boxes on the same row.
        let items: [(String, CGRect)] = [
            ("245,50", CGRect(x: 0.7, y: 0.30, width: 0.2, height: 0.03)),
            ("TOTAL TTC", CGRect(x: 0.1, y: 0.305, width: 0.3, height: 0.03)),
            ("MARJANE", CGRect(x: 0.3, y: 0.9, width: 0.4, height: 0.05))
        ]
        #expect(TextRecognizer.groupIntoLines(items) == ["MARJANE", "TOTAL TTC 245,50"])
    }
}
