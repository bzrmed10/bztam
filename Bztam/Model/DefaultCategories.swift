import Foundation

/// The categories a new user starts with, in Home order. Fixed ones are planned first.
enum DefaultCategories {
    struct Template: Sendable {
        let key: String
        let englishName: String
        let symbol: String
        let isFixed: Bool
        /// Suggested share of monthly income, in percent.
        let suggestedPercent: Int
    }

    static let all: [Template] = [
        Template(key: "rent", englishName: "Rent", symbol: "house", isFixed: true, suggestedPercent: 35),
        Template(key: "bills", englishName: "Bills", symbol: "bolt", isFixed: true, suggestedPercent: 5),
        Template(key: "phone", englishName: "Phone & Internet", symbol: "iphone", isFixed: true, suggestedPercent: 3),
        Template(key: "courses", englishName: "Groceries", symbol: "cart", isFixed: false, suggestedPercent: 15),
        Template(key: "transport", englishName: "Transport", symbol: "car", isFixed: false, suggestedPercent: 6),
        Template(key: "food", englishName: "Café & Food", symbol: "cup.and.saucer", isFixed: false, suggestedPercent: 8),
        Template(key: "goingout", englishName: "Going out", symbol: "sparkles", isFixed: false, suggestedPercent: 8),
        Template(key: "other", englishName: "Other", symbol: "square.grid.2x2", isFixed: false, suggestedPercent: 0)
    ]

    /// Suggested budget for a template from an income, rounded down to 50 DH.
    static func suggestedBudget(_ template: Template, income: Centimes) -> Centimes {
        guard income > 0 else { return 0 }
        let raw = income * template.suggestedPercent / 100
        let step = 50 * 100
        return raw / step * step
    }
}
