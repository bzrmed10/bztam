import UIKit

/// A one-file monthly report: totals, categories against their budgets, then every entry. A4, light, readable on paper.
enum ExportPDF {
    struct CategoryLine: Sendable {
        var name: String
        var spent: Centimes
        var budget: Centimes
    }

    private nonisolated static let page = CGRect(x: 0, y: 0, width: 595, height: 842)
    private nonisolated static let margin: CGFloat = 44
    private nonisolated static let ink = UIColor(red: 0x14 / 255, green: 0x29 / 255, blue: 0x0B / 255, alpha: 1)
    private nonisolated static let muted = UIColor(red: 0x58 / 255, green: 0x64 / 255, blue: 0x52 / 255, alpha: 1)
    private nonisolated static let positive = UIColor(red: 0x2F / 255, green: 0x7A / 255, blue: 0x2B / 255, alpha: 1)
    private nonisolated static let negative = UIColor(red: 0xB3 / 255, green: 0x26 / 255, blue: 0x1E / 255, alpha: 1)
    private nonisolated static let lime = UIColor(red: 0xA6 / 255, green: 0xE3 / 255, blue: 0x6F / 255, alpha: 1)
    private nonisolated static let line = UIColor(red: 0xDD / 255, green: 0xE5 / 255, blue: 0xD6 / 255, alpha: 1)

    static func make(subtitle: String, moneyIn: Centimes, spent: Centimes, categories: [CategoryLine], rows: [ExportRow]) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: {
            let f = UIGraphicsPDFRendererFormat()
            f.documentInfo = [kCGPDFContextTitle as String: "Bztam · " + subtitle, kCGPDFContextCreator as String: "Bztam"]
            return f
        }())
        return renderer.pdfData { ctx in
            var y: CGFloat = 0
            func newPage() {
                ctx.beginPage()
                y = margin
            }
            func ensure(_ height: CGFloat) {
                if y + height > page.height - margin { newPage() }
            }
            func text(_ s: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = ink,
                      x: CGFloat = margin, width: CGFloat? = nil, align: NSTextAlignment = .left) -> CGFloat {
                let style = NSMutableParagraphStyle()
                style.alignment = align
                style.lineBreakMode = .byTruncatingTail
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color, .paragraphStyle: style
                ]
                let w = width ?? (page.width - margin - x)
                let h = ceil(UIFont.systemFont(ofSize: size, weight: weight).lineHeight)
                (s as NSString).draw(in: CGRect(x: x, y: y, width: w, height: h), withAttributes: attrs)
                return h
            }
            func rule() {
                line.setFill()
                UIRectFill(CGRect(x: margin, y: y, width: page.width - 2 * margin, height: 0.75))
            }
            let contentWidth = page.width - 2 * margin

            newPage()
            y += text("Bztam", size: 28, weight: .heavy) + 2
            y += text(subtitle, size: 13, weight: .medium, color: muted) + 22

            // Totals
            let left = moneyIn - spent
            let columns: [(String, String, UIColor)] = [
                (L10n.t("Money in"), Money.format(moneyIn, sign: true, privacy: .never), positive),
                (L10n.t("Spent"), Money.format(spent, privacy: .never), ink),
                (L10n.t("Left"), Money.format(left, privacy: .never), left < 0 ? negative : ink)
            ]
            let colWidth = contentWidth / 3
            for (i, c) in columns.enumerated() {
                let x = margin + CGFloat(i) * colWidth
                _ = text(c.0, size: 11, weight: .medium, color: muted, x: x, width: colWidth)
            }
            y += 16
            for (i, c) in columns.enumerated() {
                let x = margin + CGFloat(i) * colWidth
                _ = text(c.1, size: 20, weight: .bold, color: c.2, x: x, width: colWidth - 8)
            }
            y += 40

            // Categories
            if !categories.isEmpty {
                y += text(L10n.t("Categories"), size: 15, weight: .bold) + 10
                for c in categories {
                    ensure(34)
                    _ = text(c.name, size: 12, weight: .semibold, width: contentWidth * 0.5)
                    let right = c.budget > 0
                        ? L10n.t("%@ of %@", Money.format(c.spent, symbol: false, privacy: .never), Money.format(c.budget, privacy: .never))
                        : Money.format(c.spent, privacy: .never)
                    y += text(right, size: 12, color: c.budget > 0 && c.spent > c.budget ? negative : ink,
                              x: margin + contentWidth * 0.5, width: contentWidth * 0.5, align: .right) + 5
                    let progress = c.budget > 0 ? min(1, CGFloat(c.spent) / CGFloat(c.budget)) : 0
                    line.setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentWidth, height: 4), cornerRadius: 2).fill()
                    (c.budget > 0 && c.spent > c.budget ? negative : lime).setFill()
                    UIBezierPath(roundedRect: CGRect(x: margin, y: y, width: contentWidth * progress, height: 4), cornerRadius: 2).fill()
                    y += 16
                }
                y += 18
            }

            // Entries
            ensure(60)
            y += text(L10n.t("Entries"), size: 15, weight: .bold) + 8
            let dateW: CGFloat = 70, amountW: CGFloat = 100, categoryW: CGFloat = 120
            let titleW = contentWidth - dateW - amountW - categoryW
            func header() {
                _ = text(L10n.t("Date"), size: 10, weight: .semibold, color: muted, width: dateW)
                _ = text(L10n.t("Shop or note"), size: 10, weight: .semibold, color: muted, x: margin + dateW, width: titleW)
                _ = text(L10n.t("Category"), size: 10, weight: .semibold, color: muted, x: margin + dateW + titleW, width: categoryW)
                y += text(L10n.t("Amount"), size: 10, weight: .semibold, color: muted,
                          x: margin + contentWidth - amountW, width: amountW, align: .right) + 4
                rule()
                y += 6
            }
            header()
            if rows.isEmpty {
                y += text(L10n.t("Nothing in this period."), size: 12, color: muted)
            }
            let day = DateFormatter()
            day.locale = L10n.locale
            day.setLocalizedDateFormatFromTemplate("d MMM yy")
            for r in rows.sorted(by: { $0.date > $1.date }) {
                if y + 20 > page.height - margin {
                    newPage()
                    header()
                }
                let isIncome = r.kind == .income
                _ = text(day.string(from: r.date), size: 11, color: muted, width: dateW)
                _ = text(r.title, size: 11, weight: .medium, x: margin + dateW, width: titleW - 8)
                _ = text(r.category, size: 11, color: muted, x: margin + dateW + titleW, width: categoryW - 8)
                y += text(Money.format(r.amount, sign: isIncome, privacy: .never), size: 11, weight: .semibold, color: isIncome ? positive : ink,
                          x: margin + contentWidth - amountW, width: amountW, align: .right) + 6
            }

            y = page.height - margin + 14
            _ = text(L10n.t("Made with Bztam on %@", DateText.short(.now)), size: 9, color: muted)
        }
    }
}
