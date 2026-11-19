import SwiftData
import SwiftUI
import UIKit

/// Settings → Export: a CSV for spreadsheets or a PDF report, for a period or everything.
struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [Entry]
    @Query(sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @Query private var settingsRows: [AppSettings]
    @State private var range: ExportRange = .thisPeriod
    @State private var format: ExportFormat = .pdf
    @State private var file: ExportedFile?
    @State private var failed = false

    private var payday: Int { settingsRows.first?.payday ?? 1 }
    private var period: BudgetPeriod { range.interval(payday: payday) }
    private var selected: [Entry] { entries.filter { period.contains($0.date) } }

    var body: some View {
        let count = selected.count
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
            }
            ScreenTitle(text: L10n.t("Export"))
            Text(L10n.t("A PDF report to read or print, or a CSV file for Excel and Numbers. The file is made on your iPhone."))
                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)

            Text(L10n.t("Period")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
            FlowLayout(spacing: 8) {
                ForEach(ExportRange.allCases) { r in Chip(title: r.title, selected: range == r) { range = r } }
            }
            Text(L10n.t("Format")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
            FlowLayout(spacing: 8) {
                ForEach(ExportFormat.allCases) { f in Chip(title: f.title, selected: format == f) { format = f } }
            }

            HStack(spacing: Theme.Space.m) {
                IconCircle(symbol: format == .pdf ? "doc.richtext" : "tablecells")
                VStack(alignment: .leading, spacing: 2) {
                    Text(range == .all ? L10n.t("Everything") : DateText.period(period)).font(.bzBodyStrong)
                    Text(count == 1 ? L10n.t("1 entry") : L10n.t("%d entries", count))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                }
            }

            Spacer(minLength: 0)
            Button(L10n.t("Export")) { export() }
                .buttonStyle(.pillPrimary)
                .disabled(count == 0)
                .opacity(count == 0 ? 0.5 : 1)
                .accessibilityIdentifier("export.go")
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .sheet(item: $file) { ShareSheet(url: $0.url).ignoresSafeArea() }
        .alert(L10n.t("Couldn't make the file"), isPresented: $failed) { Button(L10n.t("OK"), role: .cancel) {} }
    }

    private func rows(_ list: [Entry]) -> [ExportRow] {
        list.map { e in
            ExportRow(date: e.date, kind: e.kind, amount: e.amount,
                      category: e.kind == .income ? e.incomeSource.title : (e.category?.displayName ?? L10n.t("Other")),
                      title: e.displayTitle, note: e.note == e.displayTitle ? "" : e.note)
        }
    }

    private func export() {
        let list = selected
        let name = ExportBuilder.filename(range, period: period, ext: format.rawValue)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        let data: Data
        switch format {
        case .csv:
            data = Data(ExportBuilder.csv(rows(list), language: L10n.code, currency: Money.currency.rawValue.uppercased()).utf8)
        case .pdf:
            let moneyIn = list.filter { $0.kind == .income }.reduce(0) { $0 + $1.amount }
            let spent = list.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amount }
            // Budgets only make sense for a single period.
            let single = range == .thisPeriod || range == .lastPeriod
            let lines = categories.compactMap { c -> ExportPDF.CategoryLine? in
                let used = list.filter { $0.kind == .expense && $0.category?.id == c.id }.reduce(0) { $0 + $1.amount }
                let budget = single ? c.budget(in: period) : 0
                guard used > 0 || (budget > 0 && !c.isArchived) else { return nil }
                return ExportPDF.CategoryLine(name: c.displayName, spent: used, budget: budget)
            }
            let uncategorized = list.filter { $0.kind == .expense && $0.category == nil }.reduce(0) { $0 + $1.amount }
            let all = lines + (uncategorized > 0 ? [ExportPDF.CategoryLine(name: L10n.t("Other"), spent: uncategorized, budget: 0)] : [])
            data = ExportPDF.make(subtitle: range == .all ? L10n.t("Everything") : DateText.period(period),
                                  moneyIn: moneyIn, spent: spent, categories: all.sorted { $0.spent > $1.spent }, rows: rows(list))
        }
        do {
            try data.write(to: url, options: .atomic)
            file = ExportedFile(url: url)
        } catch {
            failed = true
        }
    }
}

struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}

/// The system share sheet (Save to Files, Mail, WhatsApp…).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
