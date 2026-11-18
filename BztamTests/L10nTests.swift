import Foundation
import Testing
@testable import Bztam

struct L10nTests {
    private func placeholders(_ s: String) -> [String] {
        var found: [String] = []
        let chars = Array(s.replacingOccurrences(of: "%%", with: ""))
        var i = 0
        while i < chars.count {
            if chars[i] == "%", i + 1 < chars.count {
                found.append("%" + String(chars[i + 1]))
                i += 1
            }
            i += 1
        }
        return found
    }

    @Test func tableLoads() {
        #expect(Strings.table.count > 50)
    }

    @Test func everyTranslationIsFilled() {
        for (key, value) in Strings.table {
            #expect(!value.trimmingCharacters(in: .whitespaces).isEmpty, "French missing: \(key)")
        }
    }

    @Test func placeholdersMatchTheEnglishKey() {
        for (key, value) in Strings.table {
            #expect(placeholders(value) == placeholders(key), "Placeholders differ: \(key)")
        }
    }

    @Test func builtInCategoryNamesAreTranslated() {
        for template in DefaultCategories.all {
            #expect(Strings.table[template.englishName] != nil, "Category not translated: \(template.englishName)")
        }
    }

    @Test func lookupFallsBackToEnglish() {
        #expect(L10n.t("Home", language: "fr") == "Accueil")
        #expect(L10n.t("Home", language: "en") == "Home")
        #expect(L10n.t("A key nobody translated", language: "fr") == "A key nobody translated")
    }
}
