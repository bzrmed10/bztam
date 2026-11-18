import Testing
@testable import Bztam

struct MoneyTests {
    @Test func englishFormat() {
        #expect(Money.format(276_000, language: "en") == "2,760 DH")
        #expect(Money.format(24_550, language: "en") == "245.50 DH")
        #expect(Money.format(5, language: "en") == "0.05 DH")
        #expect(Money.format(123_456_700, language: "en") == "1,234,567 DH")
        #expect(Money.format(800_000, language: "en", sign: true) == "+8,000 DH")
        #expect(Money.format(-4_000, language: "en") == "−40 DH")
        #expect(Money.format(3_800, language: "en", symbol: false) == "38")
    }

    @Test func frenchFormat() {
        #expect(Money.format(276_000, language: "fr") == "2\u{202F}760 DH")
        #expect(Money.format(24_550, language: "fr") == "245,50 DH")
    }

    @Test func keypadTyping() {
        var a = AmountInput()
        for k in ["2", "4", "5", ",", "5"] { a.press(k) }
        #expect(a.centimes == 24_550)
        #expect(a.display(language: "en") == "245.5")
        #expect(a.display(language: "fr") == "245,5")
        a.press("0"); a.press("9")
        #expect(a.centimes == 24_550, "only two decimals")
        a.press("⌫"); a.press("⌫"); a.press("⌫")
        #expect(a.centimes == 24_500)
    }

    @Test func keypadEdgeCases() {
        var a = AmountInput()
        a.press(","); #expect(a.text == "0,")
        a.press(","); #expect(a.text == "0,", "one comma only")
        var b = AmountInput()
        b.press("0"); b.press("7"); #expect(b.text == "7", "no leading zero")
        var c = AmountInput()
        for _ in 0..<10 { c.press("9") }
        #expect(c.text.count == AmountInput.maxUnitsDigits)
        #expect(AmountInput().centimes == 0)
    }

    @Test func inputFromCentimes() {
        #expect(AmountInput(centimes: 3_800).text == "38")
        #expect(AmountInput(centimes: 24_550).text == "245,5")
        #expect(AmountInput(centimes: 24_505).text == "245,05")
        #expect(AmountInput(centimes: 0).text == "")
    }
}
