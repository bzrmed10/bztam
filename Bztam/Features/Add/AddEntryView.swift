import SwiftData
import SwiftUI
import UIKit

/// Add (or edit) an expense or money in: amount keypad, category or source, date and shop.
struct AddEntryView: View {
    private let editing: Entry?
    private let initialKind: EntryKind
    private let initialCategoryID: UUID?
    private let onScan: ((ScanKind) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(UndoCenter.self) private var undo
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @Query private var entries: [Entry]

    @State private var kind: EntryKind = .expense
    @State private var amount = AmountInput()
    @State private var categoryID: UUID?
    @State private var incomeSource: IncomeSource = .salary
    @State private var date = Date.now
    @State private var merchant = ""
    @State private var loaded = false
    @State private var showReceipt = false
    @State private var quickText = ""
    @State private var userPickedCategory = false
    @State private var speech = SpeechInput()
    @State private var duplicate: EntryRecord?
    @State private var repeatFrequency: Frequency?

    init(request: AddRequest, onScan: ((ScanKind) -> Void)? = nil) {
        editing = nil
        initialKind = request.kind
        initialCategoryID = request.categoryID
        self.onScan = onScan
    }

    init(editing entry: Entry) {
        editing = entry
        initialKind = entry.kind
        initialCategoryID = entry.category?.id
        onScan = nil
    }

    private var title: String {
        if editing != nil { return kind == .expense ? L10n.t("Edit expense") : L10n.t("Edit money in") }
        return kind == .expense ? L10n.t("Add expense") : L10n.t("Add money in")
    }

    private var canSave: Bool { amount.centimes > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
                SegmentedPill(options: [(EntryKind.expense, L10n.t("Expense")), (EntryKind.income, L10n.t("Money in"))],
                              selection: $kind)
                    .frame(width: 220)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.bottom, 12)

            ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            ScreenTitle(text: title)

            if editing == nil {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles").foregroundStyle(Theme.Colors.inkMuted)
                    TextField(L10n.t("Type it: taxi 20, café 38…"), text: $quickText)
                        .font(.system(size: 15, weight: .medium))
                        .submitLabel(.done)
                        .onSubmit(applyQuickText)
                        .accessibilityIdentifier("add.quick")
                    Button {
                        Task { await speech.toggle() }
                    } label: {
                        Image(systemName: speech.isListening ? "stop.fill" : "mic")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.Colors.ink)
                            .frame(width: 36, height: 36)
                            .background(speech.isListening ? Theme.Colors.brand : Theme.Colors.canvas, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(speech.isListening ? L10n.t("Stop") : L10n.t("Say it"))
                }
                .padding(.leading, 16)
                .padding(.trailing, 6)
                .frame(height: 48)
                .background(Theme.Colors.surface, in: Capsule())
            }

            if let onScan, kind == .expense {
                HStack(spacing: 8) {
                    scanButton(L10n.t("Scan"), symbol: "camera", fill: Theme.Colors.brandTint) { onScan(.camera) }
                    scanButton(L10n.t("Screenshot"), symbol: "photo", fill: Theme.Colors.surface) { onScan(.screenshot) }
                    scanButton(L10n.t("PDF"), symbol: "doc", fill: Theme.Colors.surface) { onScan(.pdf) }
                }
            } else if let name = editing?.attachmentName {
                Button { showReceipt = true } label: {
                    Label(L10n.t("View receipt"), systemImage: "doc.text.image")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.Colors.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .fullScreenCover(isPresented: $showReceipt) {
                    ImageViewer(image: AttachmentStore.image(named: name))
                }
            }

            AmountField(caption: L10n.t("Amount"), text: amount.display())
                .accessibilityIdentifier("add.amount")

            FlowLayout(spacing: 8) {
                if kind == .expense {
                    ForEach(categories) { c in
                        Chip(title: c.displayName, selected: c.id == categoryID) { categoryID = c.id; userPickedCategory = true }
                    }
                } else {
                    ForEach(IncomeSource.allCases) { s in
                        Chip(title: s.title, selected: s == incomeSource) { incomeSource = s }
                    }
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("Date")).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                    DatePicker("", selection: $date, in: ...Date.now, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind == .expense ? L10n.t("Shop or note") : L10n.t("Note"))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                    TextField(L10n.t("Optional"), text: $merchant)
                        .font(.system(size: 15, weight: .semibold))
                        .submitLabel(.done)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            }

            if editing == nil {
                Menu {
                    Picker(L10n.t("Repeat"), selection: $repeatFrequency) {
                        Text(L10n.t("Never")).tag(Frequency?.none)
                        ForEach(Frequency.allCases) { Text($0.title).tag(Frequency?.some($0)) }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 15, weight: .semibold))
                        Text(L10n.t("Repeat")).font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text(repeatFrequency?.title ?? L10n.t("Never")).font(.system(size: 15)).foregroundStyle(Theme.Colors.inkMuted)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
                    }
                    .foregroundStyle(Theme.Colors.ink)
                    .padding(.horizontal, 16)
                    .frame(height: 48)
                    .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                }
                .accessibilityIdentifier("add.repeat")
            } else if editing?.recurringID != nil {
                Label(L10n.t("Repeats automatically. Change it in Settings → Recurring."), systemImage: "arrow.triangle.2.circlepath")
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            }
            .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
            KeypadView { amount.press($0) }

            Button(editing == nil ? title : L10n.t("Save")) { checkThenSave() }
                .buttonStyle(.pillPrimary)
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.5)
                .accessibilityIdentifier("add.save")

            if let entry = editing {
                Button(L10n.t("Delete")) {
                    dismiss()
                    EntryActions.delete(entry, context: context, undo: undo)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Colors.negative)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            }
            .padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Colors.line).frame(height: 1).padding(.horizontal, -Theme.Space.l) }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.s)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.large)
        .onAppear(perform: load)
        .onChange(of: speech.transcript) { _, text in quickText = text }
        .onChange(of: speech.isListening) { was, now in
            if was && !now { applyQuickText() }
        }
        .onChange(of: merchant) { _, name in
            guard editing == nil, kind == .expense, !userPickedCategory else { return }
            if let id = CategoryMemory.category(for: name, in: entries.map { EntryRecord($0) }) { categoryID = id }
        }
        .onDisappear { speech.stop() }
        .alert(L10n.t("Already added?"), isPresented: Binding(get: { duplicate != nil }, set: { if !$0 { duplicate = nil } })) {
            Button(L10n.t("Add anyway")) { save() }
            Button(L10n.t("Cancel"), role: .cancel) {}
        } message: {
            if let d = duplicate {
                Text(L10n.t("An expense of %@ was already added on %@.", Money.format(d.amount), DateText.day(d.date)))
            }
        }
        .alert(L10n.t("Microphone or speech access is off"), isPresented: Bindable(speech).denied) {
            Button(L10n.t("OK"), role: .cancel) {}
        } message: {
            Text(L10n.t("Allow them in the Settings app, or use the keyboard's dictation key."))
        }
    }

    /// Fills the form from "taxi 20", "+8000 salaire", "khlst 50 f l9hwa".
    private func applyQuickText() {
        let q = QuickEntryParser.parse(quickText)
        guard q.amount != nil || q.categoryKey != nil || !q.text.isEmpty else { return }
        kind = q.kind
        if let a = q.amount { amount = AmountInput(centimes: a) }
        if q.kind == .income {
            incomeSource = q.incomeSource
        } else {
            let records = entries.map { EntryRecord($0) }
            if let id = CategoryMemory.category(for: q.text, in: records) {
                categoryID = id
            } else if let key = q.categoryKey, let c = categories.first(where: { $0.key == key }) {
                categoryID = c.id
            }
            userPickedCategory = categoryID != nil
        }
        if !q.text.isEmpty { merchant = q.text }
    }

    private func checkThenSave() {
        if editing == nil, kind == .expense,
           let d = DuplicateCheck.find(amount: amount.centimes, date: date, merchant: merchant, in: entries.map { EntryRecord($0) }) {
            duplicate = d
        } else {
            save()
        }
    }

    private func scanButton(_ title: String, symbol: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Theme.Colors.ink)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(fill, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        kind = initialKind
        categoryID = initialCategoryID
        if let e = editing {
            amount = AmountInput(centimes: e.amount)
            incomeSource = e.incomeSource
            date = e.date
            merchant = e.merchant.isEmpty ? e.note : e.merchant
        }
        if LaunchOptions.demoData && LaunchOptions.openScreen == "add" && editing == nil {
            amount = AmountInput(text: "38")
            categoryID = categories.first(where: { $0.key == "food" })?.id
            merchant = "Café Clock"
        }
    }

    private func save() {
        guard canSave else { return }
        let category = kind == .expense
            ? (categories.first(where: { $0.id == categoryID }) ?? categories.first(where: { $0.key == "other" }) ?? categories.last)
            : nil
        let text = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        if let e = editing {
            e.kind = kind
            e.amount = amount.centimes
            e.date = date
            e.merchant = kind == .expense ? text : ""
            e.note = kind == .income ? text : ""
            e.category = category
            e.incomeSource = incomeSource
        } else {
            let entry = Entry(kind: kind, amount: amount.centimes, date: date, merchant: kind == .expense ? text : "",
                              note: kind == .income ? text : "", category: category, incomeSource: incomeSource)
            context.insert(entry)
            if let frequency = repeatFrequency {
                let rule = RecurringRule(kind: kind, amount: entry.amount, merchant: entry.merchant, note: entry.note,
                                         category: category, incomeSource: incomeSource, frequency: frequency,
                                         startDate: date, lastGenerated: date)
                context.insert(rule)
                entry.recurringID = rule.id
            }
            try? context.save()
            BudgetAlerts.afterAdding(entry, context: context)
        }
        try? context.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
}
