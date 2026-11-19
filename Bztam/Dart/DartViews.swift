import SwiftData
import SwiftUI
import UIKit

/// Settings → Dart: the user's darts.
struct DartListView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Dart.createdAt) private var darts: [Dart]
    @State private var path = NavigationPath()
    @State private var creating = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                        Spacer()
                        Button(L10n.t("New dart")) { creating = true }
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.horizontal, 16).frame(height: 40)
                            .foregroundStyle(Theme.Colors.onBrand)
                            .background(Theme.Colors.brand, in: Capsule())
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("dart.new")
                    }
                    ScreenTitle(text: L10n.t("Dart"))
                    Text(L10n.t("Everyone pays the same each month and one person collects the pot, in turn. Bztam keeps track of who paid and whose turn it is."))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)

                    if darts.isEmpty {
                        EmptyState(symbol: "person.3", title: L10n.t("No dart yet"),
                                   message: L10n.t("Add the members in turn order and the monthly amount."))
                    }
                    ForEach(darts) { dart in
                        NavigationLink(value: dart) { DartRow(dart: dart) }.buttonStyle(.plain)
                    }
                }
                .padding(Theme.Space.l)
                .foregroundStyle(Theme.Colors.ink)
            }
            .background(Theme.Colors.canvas)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Dart.self) { DartDetailView(dart: $0) }
            .sheet(isPresented: $creating) { DartEditSheet(dart: nil) }
            .onAppear {
                if LaunchOptions.openScreen == "dart", path.isEmpty, let first = darts.first { path.append(first) }
            }
        }
    }
}

struct DartRow: View {
    let dart: Dart

    var body: some View {
        let plan = dart.plan
        HStack(spacing: Theme.Space.m) {
            IconCircle(symbol: "person.3")
            VStack(alignment: .leading, spacing: 2) {
                Text(dart.name).font(.bzBodyStrong).lineLimit(1)
                Text(DartText.status(dart)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money.format(plan.pot)).font(.bzAmount)
                Text(L10n.t("per turn")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
        .frame(minHeight: Theme.Size.row)
        .contentShape(Rectangle())
    }
}

enum DartText {
    @MainActor static func status(_ dart: Dart, now: Date = .now) -> String {
        let plan = dart.plan
        switch plan.status(on: now) {
        case .notStarted(let first):
            return L10n.t("Starts %@", DateText.short(first))
        case .round(let r):
            return L10n.t("Turn %d of %d · %@ collects", r + 1, plan.count, dart.displayName(plan.collector(ofRound: r)))
        case .finished:
            return L10n.t("Finished")
        }
    }
}

/// One dart: this turn (who paid, who collects), the user's totals, and every turn.
struct DartDetailView: View {
    @Bindable var dart: Dart
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var editing = false

    var body: some View {
        let plan = dart.plan
        let status = plan.status()
        let current: Int? = {
            switch status {
            case .notStarted: 0
            case .round(let r): r
            case .finished: nil
            }
        }()

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    CircleIconButton(symbol: "chevron.left", label: L10n.t("Back")) { dismiss() }
                    Spacer()
                    Button(L10n.t("Edit")) { editing = true }
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(Theme.Colors.surface, in: Capsule())
                        .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(dart.name + " · " + L10n.t("per turn")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    Text(Money.format(plan.pot))
                        .font(.bzAmountHero).tracking(-1.2)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(L10n.t("%@ each a month · %d people", Money.format(plan.amount), plan.count))
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
                }

                if let current { thisTurn(current, started: status != .notStarted(first: plan.start)) }
                else { TagPill(text: L10n.t("Finished")) }

                totals(plan)
                turns(plan, current: current)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.top, Theme.Space.m)
            .padding(.bottom, Theme.Space.l)
            .foregroundStyle(Theme.Colors.ink)
        }
        .background(Theme.Colors.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editing) { DartEditSheet(dart: dart, onDelete: { dismiss() }) }
    }

    private func thisTurn(_ r: Int, started: Bool) -> some View {
        let plan = dart.plan
        let collector = plan.collector(ofRound: r)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle(text: started ? L10n.t("This turn") : L10n.t("First turn"))
                Spacer()
                TagPill(text: L10n.t("%d of %d paid", plan.paidCount(round: r), plan.count))
            }
            Text(L10n.t("Turn %d · %@", r + 1, DateText.short(plan.date(ofRound: r))) + " · "
                 + (collector == dart.meIndex ? L10n.t("you collect") : L10n.t("%@ collects", dart.displayName(collector))))
                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)

            if collector == dart.meIndex && started {
                let got = dart.received.contains(r)
                Button(got ? L10n.t("Collected %@", Money.format(plan.pot)) : L10n.t("I collected %@", Money.format(plan.pot))) {
                    DartActions.toggleReceived(dart, context: context)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
                .buttonStyle(.pillPrimary)
                .opacity(got ? 0.6 : 1)
            }

            VStack(spacing: 0) {
                ForEach(0..<plan.count, id: \.self) { m in
                    let paid = plan.hasPaid(m, round: r)
                    Button {
                        DartActions.togglePaid(dart, member: m, round: r, context: context)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        HStack(spacing: Theme.Space.m) {
                            Image(systemName: paid ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundStyle(paid ? Theme.Colors.positive : Theme.Colors.line)
                            Text(dart.displayName(m)).font(.bzBodyStrong)
                            if m == collector { TagPill(text: L10n.t("Collects")) }
                            Spacer()
                            Text(paid ? L10n.t("Paid") : Money.format(plan.amount))
                                .font(.bzAmount)
                                .foregroundStyle(paid ? Theme.Colors.positive : Theme.Colors.inkMuted)
                        }
                        .frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(paid ? .isSelected : [])
                }
            }
            if dart.tracksMoney {
                Text(L10n.t("Ticking yourself adds the payment to your expenses."))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
        }
    }

    private func totals(_ plan: DartPlan) -> some View {
        HStack(spacing: 12) {
            stat(L10n.t("You paid"), Money.format(plan.myPaidTotal))
            if dart.received.contains(plan.myRound) {
                stat(L10n.t("You collected"), Money.format(plan.pot))
            } else {
                stat(L10n.t("Your turn"), DateText.short(plan.date(ofRound: plan.myRound)))
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            Text(value).font(.system(size: 20, weight: .bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func turns(_ plan: DartPlan, current: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle(text: L10n.t("Turns"))
            ForEach(0..<plan.count, id: \.self) { r in
                let collector = plan.collector(ofRound: r)
                let done = plan.paidCount(round: r) == plan.count
                HStack(spacing: Theme.Space.m) {
                    Text("\(r + 1)")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(r == current ? Theme.Colors.onBrand : Theme.Colors.ink)
                        .background(r == current ? Theme.Colors.brand : Theme.Colors.surface, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dart.displayName(collector)).font(.bzBodyStrong)
                        Text(DateText.short(plan.date(ofRound: r))).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    }
                    Spacer()
                    if done {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.positive)
                            .accessibilityLabel(L10n.t("Everyone paid"))
                    } else if let current, r <= current {
                        Text(L10n.t("%d of %d paid", plan.paidCount(round: r), plan.count))
                            .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    }
                }
                .frame(minHeight: 52)
            }
        }
    }
}

/// Member being edited; `isMe` marks the user's place in the turn order.
private struct MemberDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var isMe = false
}

/// Create or change a dart.
struct DartEditSheet: View {
    let dart: Dart?
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]
    @State private var name = ""
    @State private var amount = AmountInput()
    @State private var start = Date()
    @State private var members: [MemberDraft] = [MemberDraft(name: "", isMe: true)]
    @State private var newMember = ""
    @State private var tracksMoney = true
    @State private var reminders = true
    @State private var categoryKey = "other"
    @State private var editingAmount = false
    @State private var confirmDelete = false
    @FocusState private var addFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount.centimes > 0 && members.count >= 2
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                }
                ScreenTitle(text: dart == nil ? L10n.t("New dart") : L10n.t("Edit dart"))

                field(L10n.t("Name")) {
                    TextField(L10n.t("Family, work…"), text: $name).font(.bzBodyStrong)
                }
                Button { editingAmount = true } label: {
                    AmountField(caption: L10n.t("Each person pays a month"), text: amount.display())
                }
                .buttonStyle(.plain)
                field(L10n.t("First turn")) {
                    DatePicker(L10n.t("First turn"), selection: $start, displayedComponents: .date)
                        .labelsHidden()
                        .tint(Theme.Colors.link)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L10n.t("Members in turn order")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                        Spacer()
                        if amount.centimes > 0 && members.count > 1 {
                            Text(L10n.t("%@ per turn", Money.format(amount.centimes * members.count)))
                                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }
                    ForEach(Array(members.enumerated()), id: \.element.id) { item in
                        memberRow(item.offset, item.element)
                    }
                    HStack(spacing: 8) {
                        TextField(L10n.t("Add a member"), text: $newMember)
                            .font(.bzBody)
                            .focused($addFocused)
                            .submitLabel(.done)
                            .onSubmit { addMember() }
                            .accessibilityIdentifier("dart.member")
                        Button { addMember() } label: {
                            Image(systemName: "plus").font(.system(size: 15, weight: .bold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(Theme.Colors.onBrand)
                                .background(Theme.Colors.brand, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.t("Add a member"))
                    }
                    .padding(.leading, 16).padding(.trailing, 6).frame(height: 48)
                    .background(Theme.Colors.surface, in: Capsule())
                }

                VStack(spacing: 0) {
                    ToggleRow(symbol: "arrow.left.arrow.right", title: L10n.t("Add to my money"),
                              detail: L10n.t("Your payments become expenses, the pot becomes money in"), isOn: $tracksMoney)
                    ToggleRow(symbol: "bell", title: L10n.t("Reminders"),
                              detail: L10n.t("A notification at 9:00 on each turn day"), isOn: $reminders)
                }
                if tracksMoney {
                    Text(L10n.t("Category for your payments")).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
                    FlowLayout(spacing: 8) {
                        ForEach(categories) { c in
                            Chip(title: c.displayName, selected: categoryKey == c.key) { categoryKey = c.key }
                        }
                    }
                }

                Button(L10n.t("Save")) { save() }
                    .buttonStyle(.pillPrimary)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .accessibilityIdentifier("dart.save")

                if dart != nil {
                    Button(L10n.t("Delete dart")) { confirmDelete = true }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.negative)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(Theme.Space.l)
            .foregroundStyle(Theme.Colors.ink)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.canvas)
        .sheet(isPresented: $editingAmount) { AmountEditSheet(title: L10n.t("Each person pays a month"), input: $amount) }
        .confirmationDialog(L10n.t("Delete this dart?"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t("Delete dart"), role: .destructive) {
                if let dart { context.delete(dart) }
                try? context.save()
                DartActions.scheduleReminders(context: context)
                dismiss()
                onDelete()
            }
        } message: {
            Text(L10n.t("Expenses and money in already added stay."))
        }
        .onAppear(perform: load)
    }

    private func field<Content: View>(_ caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
            content()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func memberRow(_ index: Int, _ m: MemberDraft) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 32, height: 32)
                .foregroundStyle(m.isMe ? Theme.Colors.onBrand : Theme.Colors.ink)
                .background(m.isMe ? Theme.Colors.brand : Theme.Colors.surface, in: Circle())
            Text(m.isMe ? L10n.t("You") : m.name).font(.bzBodyStrong).lineLimit(1)
            Spacer()
            Button { move(index, by: -1) } label: { Image(systemName: "chevron.up").frame(width: 36, height: 36) }
                .disabled(index == 0).opacity(index == 0 ? 0.3 : 1)
                .accessibilityLabel(L10n.t("Earlier turn"))
            Button { move(index, by: 1) } label: { Image(systemName: "chevron.down").frame(width: 36, height: 36) }
                .disabled(index == members.count - 1).opacity(index == members.count - 1 ? 0.3 : 1)
                .accessibilityLabel(L10n.t("Later turn"))
            if !m.isMe {
                Button { members.remove(at: index) } label: {
                    Image(systemName: "minus.circle").foregroundStyle(Theme.Colors.negative).frame(width: 36, height: 36)
                }
                .accessibilityLabel(L10n.t("Remove"))
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func move(_ index: Int, by delta: Int) {
        let target = index + delta
        guard members.indices.contains(target) else { return }
        withAnimation(.snappy) { members.swapAt(index, target) }
    }

    private func addMember() {
        let n = newMember.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return }
        members.append(MemberDraft(name: n))
        newMember = ""
        addFocused = true
    }

    private func load() {
        guard let dart else { return }
        name = dart.name
        amount = AmountInput(centimes: dart.amount)
        start = dart.startDate
        members = dart.memberNames.enumerated().map { MemberDraft(name: $0.element, isMe: $0.offset == dart.meIndex) }
        if !members.contains(where: \.isMe) { members.insert(MemberDraft(name: "", isMe: true), at: 0) }
        tracksMoney = dart.tracksMoney
        reminders = dart.reminders
        categoryKey = dart.categoryKey
    }

    private func save() {
        addMember()
        let names = members.map { $0.isMe ? "" : $0.name }
        let me = members.firstIndex(where: \.isMe) ?? 0
        let target: Dart
        if let dart {
            target = dart
            target.name = name.trimmingCharacters(in: .whitespaces)
            target.amount = amount.centimes
            target.startDate = start
            target.memberNames = names
            target.meIndex = me
        } else {
            target = Dart(name: name.trimmingCharacters(in: .whitespaces), amount: amount.centimes, startDate: start,
                          memberNames: names, meIndex: me)
            context.insert(target)
        }
        target.tracksMoney = tracksMoney
        target.reminders = reminders
        target.categoryKey = categoryKey
        try? context.save()
        DartActions.scheduleReminders(context: context)
        dismiss()
    }
}

/// Home card: "Family dart: pay 1,000 DH · Sara collects" or "Your turn to collect 5,000 DH".
struct DartCard: View {
    let dart: Dart
    let collect: Bool
    let action: () -> Void

    var body: some View {
        let plan = dart.plan
        HStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Theme.Colors.canvas, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(collect ? L10n.t("Your turn to collect %@", Money.format(plan.pot))
                             : L10n.t("Pay %@ for %@", Money.format(plan.amount), dart.name))
                    .font(.system(size: 15, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.85)
                Text(DartText.status(dart)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted).lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(collect ? L10n.t("Collected") : L10n.t("Paid"), action: action)
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 14)
                .frame(height: 36)
                .foregroundStyle(Theme.Colors.onBrand)
                .background(Theme.Colors.brand, in: Capsule())
                .buttonStyle(.plain)
                .accessibilityIdentifier("home.dart")
        }
        .padding(12)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
}
