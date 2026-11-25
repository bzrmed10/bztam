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
    @State private var splitting: SplitDraft?
    @State private var keyboardShown = false
    @State private var pickingDate = false
    @State private var addingCategory = false

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
            topBar
                .padding(.bottom, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if editing != nil { ScreenTitle(text: title) }
                        if editing == nil { quickField }
                        amountView
                        categoryRow(proxy)
                        shopField
                        optionsRow
                        if editing?.splitID != nil {
                            Label(L10n.t("Part of a split with friends. Balances are in Friends."), systemImage: "person.2")
                                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        } else if editing?.recurringID != nil {
                            Label(L10n.t("Repeats automatically. Change it in Plan → Every month."), systemImage: "arrow.triangle.2.circlepath")
                                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }
                    .padding(.bottom, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
                .onChange(of: categoryID) { _, id in
                    guard let id else { return }
                    withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
                }
            }

            VStack(spacing: 10) {
                if keyboardShown {
                    // The system keyboard is up (typing a shop or a sentence): one tap brings the keypad back.
                    HStack {
                        Spacer()
                        Button(action: hideKeyboard) {
                            Label(L10n.t("Keypad"), systemImage: "keyboard.chevron.compact.down")
                                .font(.scaled(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.Colors.ink)
                                .padding(.horizontal, 16)
                                .frame(height: 40)
                                .background(Theme.Colors.surface, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                        .accessibilityLabel(L10n.t("Back to the keypad"))
                        .accessibilityIdentifier("add.keypad")
                    }
                    .transition(.opacity)
                } else {
                    KeypadView { amount.press($0) }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

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
                    .font(.scaled(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.negative)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(.top, 8)
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.m)
        .padding(.bottom, Theme.Space.s)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
        .presentationCornerRadius(Theme.Radius.large)
        .sheet(item: $splitting) { d in
            SplitSheet(draft: d) { dismiss() }
        }
        .sheet(isPresented: $addingCategory) {
            CategoryEditSheet(category: nil, nextOrder: (categories.map(\.order).max() ?? 0) + 1) { new in
                categoryID = new.id
                userPickedCategory = true
            }
        }
        .sheet(isPresented: $pickingDate) { dateSheet }
        .fullScreenCover(isPresented: $showReceipt) {
            ImageViewer(image: AttachmentStore.image(named: editing?.attachmentName ?? ""))
        }
        .onAppear(perform: load)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.snappy) { keyboardShown = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.snappy) { keyboardShown = false }
        }
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

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 8) {
            CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
            SegmentedPill(options: [(EntryKind.expense, L10n.t("Expense")), (EntryKind.income, L10n.t("Money in"))],
                          selection: $kind)
                .frame(maxWidth: 210)
            Spacer(minLength: 0)
            if let onScan, kind == .expense {
                CircleIconButton(symbol: "camera", label: L10n.t("Scan a receipt")) { onScan(.camera) }
                Menu {
                    Button { onScan(.screenshot) } label: { Label(L10n.t("Screenshot or photo"), systemImage: "photo") }
                    Button { onScan(.pdf) } label: { Label(L10n.t("PDF bill"), systemImage: "doc") }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.scaled(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.surface, in: Circle())
                }
                .accessibilityLabel(L10n.t("Import a screenshot or PDF"))
                .accessibilityIdentifier("add.import")
            } else if editing?.attachmentName != nil {
                CircleIconButton(symbol: "doc.text.image", label: L10n.t("View receipt")) { showReceipt = true }
            }
        }
    }

    private var quickField: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(Theme.Colors.inkMuted)
            TextField(L10n.t("Type it: taxi 20, café 38…"), text: $quickText)
                .font(.scaled(size: 15, weight: .medium))
                .submitLabel(.done)
                .onSubmit(applyQuickText)
                .accessibilityIdentifier("add.quick")
            Button {
                Task { await speech.toggle() }
            } label: {
                Image(systemName: speech.isListening ? "stop.fill" : "mic")
                    .symbolEffect(.pulse, isActive: speech.isListening)
                    .font(.scaled(size: 15, weight: .bold))
                    .foregroundStyle(speech.isListening ? Theme.Colors.onBrand : Theme.Colors.ink)
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

    private var amountView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(amount.display())
                .font(.scaled(size: 56, weight: .heavy).monospacedDigit())
                .tracking(-1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: amount.display())
            Text(Money.currencySymbol)
                .font(.scaled(size: 22, weight: .bold))
                .foregroundStyle(Theme.Colors.inkMuted)
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t("Amount"))
        .accessibilityValue(amount.display() + " " + Money.currencySymbol)
        .accessibilityIdentifier("add.amount")
    }

    /// One sideways row: the categories you use most first, the one picked always visible.
    private func categoryRow(_ proxy: ScrollViewProxy) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if kind == .expense {
                    ForEach(orderedCategories) { c in
                        Chip(title: c.displayName, selected: c.id == categoryID) { categoryID = c.id; userPickedCategory = true }
                            .id(c.id)
                    }
                    AddChip { addingCategory = true }
                } else {
                    ForEach(IncomeSource.allCases) { s in
                        Chip(title: s.title, selected: s == incomeSource) { incomeSource = s }
                    }
                }
            }
            .padding(.horizontal, Theme.Space.l)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Theme.Space.l)
    }

    private var shopField: some View {
        HStack(spacing: 10) {
            Image(systemName: kind == .expense ? "bag" : "text.alignleft")
                .font(.scaled(size: 15, weight: .medium))
                .foregroundStyle(Theme.Colors.inkMuted)
            TextField(kind == .expense ? L10n.t("Shop or note") : L10n.t("Note"), text: $merchant)
                .font(.scaled(size: 15, weight: .semibold))
                .submitLabel(.done)
                .accessibilityIdentifier("add.shop")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    /// Date, Repeat and Split side by side; each opens a small sheet or menu.
    private var optionsRow: some View {
        HStack(spacing: 8) {
            Button { hideKeyboard(); pickingDate = true } label: {
                optionLabel("calendar", dateTitle, active: !Calendar.current.isDateInToday(date))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("add.date")
            if editing == nil {
                Menu {
                    Picker(L10n.t("Repeat"), selection: $repeatFrequency) {
                        Text(L10n.t("Never")).tag(Frequency?.none)
                        ForEach(Frequency.allCases) { Text($0.title).tag(Frequency?.some($0)) }
                    }
                } label: {
                    optionLabel("arrow.triangle.2.circlepath", repeatFrequency?.title ?? L10n.t("Repeat"), active: repeatFrequency != nil)
                }
                .accessibilityIdentifier("add.repeat")
                if kind == .expense {
                    Button {
                        hideKeyboard()
                        splitting = SplitDraft(amount: amount.centimes, merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                                               date: date, categoryID: categoryID)
                    } label: {
                        optionLabel("person.2", L10n.t("Split"), active: false)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel(L10n.t("Split with friends"))
                    .accessibilityIdentifier("add.split")
                }
            }
        }
    }

    private func optionLabel(_ symbol: String, _ text: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.scaled(size: 14, weight: .semibold))
            Text(text).font(.scaled(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .foregroundStyle(active ? Theme.Colors.onInk : Theme.Colors.ink)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background(active ? Theme.Colors.ink : Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private var dateTitle: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return L10n.t("Today") }
        if cal.isDateInYesterday(date) { return L10n.t("Yesterday") }
        return DateText.short(date)
    }

    private var dateSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("Date")).font(.bzTitle)
                Spacer()
                Button(L10n.t("Done")) { pickingDate = false }
                    .font(.scaled(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.link)
            }
            HStack(spacing: 8) {
                Chip(title: L10n.t("Today"), selected: Calendar.current.isDateInToday(date)) { date = .now; pickingDate = false }
                Chip(title: L10n.t("Yesterday"), selected: Calendar.current.isDateInYesterday(date)) {
                    date = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
                    pickingDate = false
                }
            }
            DatePicker(L10n.t("Date"), selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Theme.Colors.positive)
        }
        .padding(Theme.Space.l)
        .frame(maxHeight: .infinity, alignment: .top)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Most used in the last 60 days first, then the usual order.
    private var orderedCategories: [BudgetCategory] {
        let since = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .distantPast
        var uses: [UUID: Int] = [:]
        for e in entries where e.kind == .expense && e.date >= since {
            if let id = e.category?.id { uses[id, default: 0] += 1 }
        }
        return categories.enumerated().sorted { a, b in
            let ua = uses[a.element.id] ?? 0, ub = uses[b.element.id] ?? 0
            return ua != ub ? ua > ub : a.offset < b.offset
        }.map(\.element)
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

    private func load() {
        guard !loaded else { return }
        loaded = true
        kind = initialKind
        categoryID = initialCategoryID
        if let e = editing {
            amount = AmountInput(centimes: abs(e.amount))
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
            // A friend paying back is stored negative (a refund); keep the sign.
            e.amount = e.amount < 0 ? -amount.centimes : amount.centimes
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
            let ctx = context
            let ruleID = entry.recurringID
            undo.show(L10n.t("Added %@", Money.format(entry.amount, privacy: kind == .income ? .income : .any)), success: true) {
                if let ruleID {
                    let rules = (try? ctx.fetch(FetchDescriptor<RecurringRule>())) ?? []
                    for r in rules where r.id == ruleID { ctx.delete(r) }
                }
                ctx.delete(entry)
                try? ctx.save()
            }
        }
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
