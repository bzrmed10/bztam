import SwiftData
import SwiftUI

/// Shared entry operations used by several screens.
@MainActor
enum EntryActions {
    /// Deletes an entry and offers Undo, which puts back an identical copy.
    static func delete(_ entry: Entry, context: ModelContext, undo: UndoCenter) {
        let kind = entry.kind, amount = entry.amount, date = entry.date
        let merchant = entry.merchant, note = entry.note, category = entry.category
        let incomeSource = entry.incomeSource, source = entry.source, attachment = entry.attachmentName
        context.delete(entry)
        try? context.save()
        undo.show(L10n.t("Deleted")) {
            let copy = Entry(kind: kind, amount: amount, date: date, merchant: merchant, note: note,
                             category: category, incomeSource: incomeSource, source: source)
            copy.attachmentName = attachment
            context.insert(copy)
            try? context.save()
        }
    }
}

/// One entry in a list: icon or letter circle, title, details, amount.
struct EntryRow: View {
    let entry: Entry
    var showsDate = false

    private var details: String {
        var parts: [String] = []
        if showsDate { parts.append(DateText.day(entry.date)) }
        if entry.kind == .income {
            parts.append(L10n.t("Money in"))
        } else if let c = entry.category {
            parts.append(c.displayName)
        }
        switch entry.source {
        case .camera: parts.append(L10n.t("Receipt"))
        case .screenshot: parts.append(L10n.t("Screenshot"))
        case .share: parts.append(L10n.t("Shared"))
        case .manual, .recurring: break
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: Theme.Space.m) {
            if entry.kind == .income {
                IconCircle(symbol: "arrow.down.to.line", fill: Theme.Colors.brandTint, tint: Theme.Colors.positive)
            } else if let c = entry.category {
                IconCircle(symbol: c.symbol)
            } else {
                LetterCircle(text: entry.displayTitle)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayTitle).font(.bzBodyStrong).foregroundStyle(Theme.Colors.ink).lineLimit(1)
                if !details.isEmpty {
                    Text(details).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            // A friend paying back is a negative expense (a refund into the category): show it as money coming back.
            let back = entry.kind == .expense && entry.amount < 0
            Text(Money.format(back ? -entry.amount : entry.amount, sign: entry.kind == .income || back))
                .font(.bzAmount)
                .foregroundStyle(entry.kind == .income || back ? Theme.Colors.positive : Theme.Colors.ink)
        }
        .frame(minHeight: Theme.Size.row)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
