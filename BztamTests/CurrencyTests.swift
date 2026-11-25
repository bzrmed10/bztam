import Foundation
import Testing
@testable import Bztam

struct CurrencyTests {
    @Test func dirhamLimitsStayTheSame() {
        #expect(Currency.mad.scaled(5_000) == 5_000)
        #expect(Currency.mad.scaled(20_000) == 20_000)
    }

    @Test func limitsAreRoundInEveryCurrency() {
        // 50 DH ≈ 5 €; ≈ 3,000 FCFA → 2,000 FCFA; ≈ 650 DA → 500 DA; ≈ 1.5 KWD → 2 KWD.
        #expect(Currency.eur.scaled(5_000) == 500)
        #expect(Currency.xof.scaled(5_000) == 200_000)
        #expect(Currency.dzd.scaled(5_000) == 50_000)
        #expect(Currency.kwd.scaled(5_000) == 200)
        for c in Currency.allCases {
            let v = c.scaled(5_000)
            #expect(v > 0)
            if !c.hasCents { #expect(v % 100 == 0) }
        }
    }

    @Test func currenciesWithoutCentsShowWholeAmounts() {
        #expect(Money.format(1_250_050, language: "fr", currency: .xof) == "12\u{202F}501 FCFA")
        #expect(Money.format(150_000, language: "en", currency: .jpy) == "¥1,500")
        #expect(Money.format(24_550, language: "en", currency: .tnd) == "245.50 DT")
        #expect(Money.format(24_550, language: "en", currency: .eur) == "€245.50")
    }

    @Test func everyCurrencyHasASymbolAndAName() {
        for c in Currency.allCases {
            #expect(!c.symbol.isEmpty)
            #expect(!c.name.isEmpty)
            #expect(c.code.count == 3)
        }
        #expect(Currency(rawValue: "try") == .try_)
    }

    @Test func regionCurrencyComesFirst() {
        let list = Currency.sorted(region: .dzd)
        #expect(list.first == .dzd)
        #expect(list.count == Currency.allCases.count)
        #expect(Currency.sorted(region: nil).first == .mad)
    }

    @Test func search() {
        #expect(Currency.dzd.matches("DA"))
        #expect(Currency.dzd.matches("dzd"))
        #expect(!Currency.eur.matches("dinar"))
        #expect(Currency.eur.matches(""))
    }

    @Test func familyComesSecondAbroad() {
        #expect(BillCatalog.shown(abroad: true)[1].id == "family")
        #expect(BillCatalog.shown(abroad: true)[1].title == "Sent to family")
        #expect(BillCatalog.shown(abroad: false) == BillCatalog.kinds)
    }
}
