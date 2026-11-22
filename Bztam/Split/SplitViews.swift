import SwiftData
import SwiftUI
import UIKit

/// What a split starts from: a scanned ticket or the Add sheet.
struct SplitDraft: Identifiable {
    let id = UUID()
    var amount: Centimes = 0
    var merchant: String = ""
    var date: Date = .now
    var categoryID: UUID?
}

/// Split a bill equally with friends from your list.
struct SplitSheet: View {
    let draft: SplitDraft
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Friend.name) private var friends: [Friend]
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]

    @State private var amount = AmountInput()
    @State private var merchant = ""
    @State private var date = Date()
    @State private var categoryID: UUID?
    @State private var selected: [UUID] = []
    @State private var payerID: UUID?
    @State private var includesMe = true
    @State private var remind = true
    @State private var newFriend = ""
    @State private var editingAmount = false
    @State private var saved: (lines: [SplitActions.Line], message: String)?
    @FocusState private var addFocused: Bool

    private var chosen: [Friend] { selected.compactMap { id in friends.first { $0.id == id } } }
    private var meIn: Bool { payerID == nil ? includesMe : true }
    private var people: Int { chosen.count + (meIn ? 1 : 0) }
    private var canSave: Bool { amount.centimes > 0 && !chosen.isEmpty }
    private var each: Centimes { people > 0 ? amount.centimes / people : 0 }

    var body: some View {
        Group {
            if let saved { done(saved) } else { form }
        }
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .keyboardDoneButton()
        .presentationDetents([.large])
        .sheet(isPresented: $editingAmount) { AmountEditSheet(title: L10n.t("Total to split"), input: $amount) }
        .onAppear {
            amount = AmountInput(centimes: draft.amount)
            merchant = draft.merchant
            date = draft.date
            categoryID = draft.categoryID ?? categories.first { $0.key == "goingout" }?.id
        }
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                }
                ScreenTitle(text: L10n.t("Split with friends"))

                Button { editingAmount = true } label: {
                    AmountField(caption: L10n.t("Total to split"), text: amount.display())
                }
                .buttonStyle(.plain)

                field(L10n.t("Shop or note")) {
                    TextField(L10n.t("Optional"), text: $merchant).font(.bzBodyStrong)
                }

                // Who's in
                VStack(alignment: .leading, spacing: 8) {
                    label(L10n.t("Who's in"))
                    FlowLayout(spacing: 8) {
                        ForEach(friends) { f in
                            Chip(title: f.name, selected: selected.contains(f.id)) { toggle(f.id) }
                        }
                    }
                    HStack(spacing: 8) {
                        TextField(friends.isEmpty ? L10n.t("Add your first friend") : L10n.t("Add a friend"), text: $newFriend)
                            .font(.bzBody)
                            .focused($addFocused)
                            .submitLabel(.done)
                            .onSubmit(addFriend)
                            .accessibilityIdentifier("split.friend")
                        Button(action: addFriend) {
                            Image(systemName: "plus").font(.scaled(size: 15, weight: .bold))
                                .frame(width: 36, height: 36)
                                .background(Theme.Colors.brand, in: Circle())
                                .foregroundStyle(Theme.Colors.onBrand)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.t("Add a friend"))
                    }
                    .padding(.leading, 16).padding(.trailing, 6).frame(height: 48)
                    .background(Theme.Colors.surface, in: Capsule())
                }

                // Who paid
                VStack(alignment: .leading, spacing: 8) {
                    label(L10n.t("Who paid?"))
                    FlowLayout(spacing: 8) {
                        Chip(title: L10n.t("You"), selected: payerID == nil) { payerID = nil }
                        ForEach(chosen) { f in
                            Chip(title: f.name, selected: payerID == f.id) { payerID = f.id }
                        }
                    }
                }

                if payerID == nil {
                    VStack(spacing: 0) {
                        ToggleRow(symbol: "person", title: L10n.t("Include me"),
                                  detail: L10n.t("Off if you paid for the others only"), isOn: $includesMe)
                        ToggleRow(symbol: "bell", title: L10n.t("Remind me in 3 days"),
                                  detail: L10n.t("If friends haven't paid you back"), isOn: $remind)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    label(L10n.t("Category"))
                    FlowLayout(spacing: 8) {
                        ForEach(categories) { c in
                            Chip(title: c.displayName, selected: categoryID == c.id) { categoryID = c.id }
                        }
                    }
                }

                // Preview
                if canSave {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.t("%@ each · %d people", Money.format(each), people))
                            .font(.scaled(size: 20, weight: .bold))
                        Text(payerID == nil
                             ? L10n.t("The %@ leaves your money now. What friends pay back comes back into %@.",
                                      Money.format(amount.centimes), categoryName)
                             : L10n.t("Nothing leaves your money now. When you pay %@ your %@, it's added as spent.",
                                      chosen.first { $0.id == payerID }?.name ?? "", Money.format(each)))
                            .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.brandTint, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
                }

                Button(L10n.t("Split")) { save() }
                    .buttonStyle(.pillPrimary)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                    .accessibilityIdentifier("split.save")
            }
            .padding(Theme.Space.l)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func done(_ saved: (lines: [SplitActions.Line], message: String)) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            ScreenTitle(text: L10n.t("Split saved"))
            VStack(spacing: 0) {
                ForEach(saved.lines) { l in
                    HStack {
                        LetterCircle(text: l.name)
                        Text(l.name).font(.bzBodyStrong)
                        if l.isPayer { TagPill(text: L10n.t("Paid")) }
                        Spacer()
                        Text(Money.format(l.amount)).font(.bzAmount)
                    }
                    .frame(minHeight: 56)
                }
            }
            Spacer(minLength: 0)
            ShareLink(item: saved.message) {
                Label(L10n.t("Share on WhatsApp"), systemImage: "square.and.arrow.up")
                    .font(.scaled(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: Theme.Size.button)
                    .background(Theme.Colors.brand, in: Capsule())
                    .foregroundStyle(Theme.Colors.onBrand)
            }
            .accessibilityIdentifier("split.share")
            Button(L10n.t("Done")) {
                dismiss()
                onDone()
            }
            .font(.scaled(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(Theme.Space.l)
    }

    private var categoryName: String { categories.first { $0.id == categoryID }?.displayName ?? L10n.t("Other") }

    private func label(_ text: String) -> some View {
        Text(text).font(.scaled(size: 14, weight: .bold)).foregroundStyle(Theme.Colors.inkMuted)
    }

    private func field<Content: View>(_ caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption).font(.scaled(size: 12, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)
            content()
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func toggle(_ id: UUID) {
        if let i = selected.firstIndex(of: id) {
            selected.remove(at: i)
            if payerID == id { payerID = nil }
        } else {
            selected.append(id)
        }
    }

    private func addFriend() {
        let name = newFriend.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let existing = friends.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            if !selected.contains(existing.id) { selected.append(existing.id) }
        } else {
            let f = Friend(name: name)
            context.insert(f)
            try? context.save()
            selected.append(f.id)
        }
        newFriend = ""
        addFocused = true
    }

    private func save() {
        let payer = chosen.first { $0.id == payerID }
        let category = categories.first { $0.id == categoryID }
        let name = merchant.trimmingCharacters(in: .whitespaces)
        let result = SplitActions.create(merchant: name, total: amount.centimes, date: date, category: category,
                                         payer: payer, friends: chosen, includesMe: includesMe,
                                         remind: payerID == nil && remind, context: context)
        let message = SplitActions.message(merchant: name, total: amount.centimes, date: date, lines: result.lines,
                                           paidByMe: payer == nil, payerName: payer?.name)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation { saved = (result.lines, message) }
    }
}

/// Friends and balances: who owes you, who you owe.
struct FriendsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Friend.name) private var friends: [Friend]
    // Watched so balances refresh after paying back.
    @Query private var shares: [SplitShare]
    @State private var newFriend = ""
    @State private var open: Friend?
    @State private var splitting: SplitDraft?

    var body: some View {
        let balances = SplitActions.balances(context: context)
        let owed = balances.reduce(0) { $0 + $1.owesYou }
        let owe = balances.reduce(0) { $0 + $1.youOwe }
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                    Button(L10n.t("New split")) { splitting = SplitDraft() }
                        .font(.scaled(size: 14, weight: .semibold))
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(Theme.Colors.brand, in: Capsule())
                        .foregroundStyle(Theme.Colors.onBrand)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("friends.split")
                }
                ScreenTitle(text: L10n.t("Friends"))
                HStack(spacing: 12) {
                    stat(L10n.t("Owed to you"), owed, Theme.Colors.positive)
                    stat(L10n.t("You owe"), owe, owe > 0 ? Theme.Colors.negative : Theme.Colors.ink)
                }

                if friends.isEmpty {
                    EmptyState(symbol: "person.2", title: L10n.t("No friends yet"),
                               message: L10n.t("Add the friends you go out with, then split a bill or a ticket with them."))
                }
                VStack(spacing: 0) {
                    ForEach(balances) { b in
                        Button { open = friends.first { $0.id == b.friendID } } label: { row(b) }
                            .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    TextField(L10n.t("Add a friend"), text: $newFriend)
                        .font(.bzBody)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button(action: add) {
                        Image(systemName: "plus").font(.scaled(size: 15, weight: .bold))
                            .frame(width: 36, height: 36)
                            .background(Theme.Colors.brand, in: Circle())
                            .foregroundStyle(Theme.Colors.onBrand)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Add a friend"))
                }
                .padding(.leading, 16).padding(.trailing, 6).frame(height: 48)
                .background(Theme.Colors.surface, in: Capsule())

                Text(L10n.t("Counted like your bank: when you pay, the whole bill leaves your money; what friends pay back comes back into the same category."))
                    .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            .padding(Theme.Space.l)
            .foregroundStyle(Theme.Colors.ink)
        }
        .background(Theme.Colors.canvas)
        .keyboardDoneButton()
        .sheet(item: $open) { FriendDetailSheet(friend: $0) }
        .sheet(item: $splitting) { SplitSheet(draft: $0) }
    }

    private func stat(_ title: String, _ value: Centimes, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            Text(Money.format(value)).font(.scaled(size: 22, weight: .bold).monospacedDigit()).foregroundStyle(color)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }

    private func row(_ b: FriendBalance) -> some View {
        HStack(spacing: Theme.Space.m) {
            LetterCircle(text: b.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(b.name).font(.bzBodyStrong)
                Text(FriendText.status(b)).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            }
            Spacer()
            if b.net != 0 {
                Text(Money.format(abs(b.net), sign: b.net > 0))
                    .font(.bzAmount)
                    .foregroundStyle(b.net > 0 ? Theme.Colors.positive : Theme.Colors.negative)
            }
            Image(systemName: "chevron.forward").font(.scaled(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
        }
        .frame(minHeight: Theme.Size.row)
        .contentShape(Rectangle())
    }

    private func add() {
        let name = newFriend.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !friends.contains(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            newFriend = ""
            return
        }
        context.insert(Friend(name: name))
        try? context.save()
        newFriend = ""
    }
}

enum FriendText {
    static func status(_ b: FriendBalance) -> String {
        switch (b.owesYou > 0, b.youOwe > 0) {
        case (true, true): L10n.t("Owes you %@ · you owe %@", Money.format(b.owesYou), Money.format(b.youOwe))
        case (true, false): L10n.t("Owes you %@", Money.format(b.owesYou))
        case (false, true): L10n.t("You owe %@", Money.format(b.youOwe))
        case (false, false): L10n.t("All settled")
        }
    }
}

/// One friend: what's open, paying back, reminding, renaming.
struct FriendDetailSheet: View {
    @Bindable var friend: Friend
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var shares: [SplitShare]
    @State private var paying: PayBack?
    @State private var confirmForget: Bool?
    @State private var confirmDelete = false
    @State private var renaming = false
    @State private var newName = ""

    private struct PayBack: Identifiable {
        let id = UUID()
        let fromFriend: Bool
        let open: Centimes
    }

    var body: some View {
        let b = SplitActions.balances(context: context).first { $0.friendID == friend.id }
            ?? FriendBalance(friendID: friend.id, name: friend.name, owesYou: 0, youOwe: 0)
        let bills = SplitActions.openBills(with: friend, context: context)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                    Button(L10n.t("Rename")) { newName = friend.name; renaming = true }
                        .font(.scaled(size: 14, weight: .semibold))
                        .padding(.horizontal, 16).frame(height: 40)
                        .background(Theme.Colors.surface, in: Capsule())
                        .buttonStyle(.plain)
                }
                ScreenTitle(text: friend.name)
                Text(FriendText.status(b)).font(.scaled(size: 17, weight: .medium)).foregroundStyle(Theme.Colors.inkMuted)

                if b.owesYou > 0 {
                    VStack(spacing: 10) {
                        Button(L10n.t("%@ paid me back", friend.name)) { paying = PayBack(fromFriend: true, open: b.owesYou) }
                            .buttonStyle(.pillPrimary)
                        ShareLink(item: SplitActions.reminderMessage(for: friend, context: context)) {
                            Label(L10n.t("Remind on WhatsApp"), systemImage: "bubble.left")
                                .font(.scaled(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .background(Theme.Colors.surface, in: Capsule())
                        }
                        Button(L10n.t("Forget what %@ owes", friend.name)) { confirmForget = true }
                            .font(.scaled(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
                if b.youOwe > 0 {
                    VStack(spacing: 10) {
                        Button(L10n.t("I paid %@ back", friend.name)) { paying = PayBack(fromFriend: false, open: b.youOwe) }
                            .buttonStyle(b.owesYou > 0 ? .pillSecondary : .pillPrimary)
                        Button(L10n.t("%@ said forget it", friend.name)) { confirmForget = false }
                            .font(.scaled(size: 15, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }

                if !bills.isEmpty {
                    SectionTitle(text: L10n.t("Open bills"))
                    VStack(spacing: 0) {
                        ForEach(bills, id: \.bill.id) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.bill.merchant.isEmpty ? L10n.t("Split bill") : item.bill.merchant).font(.bzBodyStrong)
                                    Text(DateText.short(item.bill.date) + " · " + Money.format(item.bill.total))
                                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                                }
                                Spacer()
                                Text(item.owesYou > 0 ? L10n.t("owes %@", Money.format(item.owesYou)) : L10n.t("you owe %@", Money.format(item.youOwe)))
                                    .font(.scaled(size: 14, weight: .semibold))
                                    .foregroundStyle(item.owesYou > 0 ? Theme.Colors.positive : Theme.Colors.negative)
                            }
                            .frame(minHeight: 56)
                        }
                    }
                }

                if b.owesYou == 0 && b.youOwe == 0 {
                    Button(L10n.t("Delete %@", friend.name)) { confirmDelete = true }
                        .font(.scaled(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.negative)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .padding(Theme.Space.l)
            .foregroundStyle(Theme.Colors.ink)
        }
        .background(Theme.Colors.canvas)
        .keyboardDoneButton()
        .sheet(item: $paying) { p in
            PayBackSheet(title: p.fromFriend ? L10n.t("%@ paid me back", friend.name) : L10n.t("I paid %@ back", friend.name),
                         open: p.open) { amount in
                if p.fromFriend {
                    SplitActions.friendPaidBack(friend, amount: amount, context: context)
                } else {
                    SplitActions.youPaidBack(friend, amount: amount, context: context)
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
        .confirmationDialog(confirmForget == true ? L10n.t("Forget what %@ owes you?", friend.name) : L10n.t("Forget what you owe %@?", friend.name),
                            isPresented: Binding(get: { confirmForget != nil }, set: { if !$0 { confirmForget = nil } }),
                            titleVisibility: .visible) {
            Button(L10n.t("Forget it"), role: .destructive) {
                if let owedToMe = confirmForget { SplitActions.forget(friend, owedToMe: owedToMe, context: context) }
                confirmForget = nil
            }
        } message: {
            Text(L10n.t("Nothing is added to your money. The bills are marked as settled."))
        }
        .confirmationDialog(L10n.t("Delete %@?", friend.name), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(L10n.t("Delete"), role: .destructive) {
                context.delete(friend)
                try? context.save()
                dismiss()
            }
        }
        .alert(L10n.t("Rename"), isPresented: $renaming) {
            TextField(L10n.t("Name"), text: $newName)
            Button(L10n.t("Save")) {
                let n = newName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { friend.name = n; try? context.save() }
            }
            Button(L10n.t("Cancel"), role: .cancel) {}
        }
    }
}

/// Amount of a payback, the full open amount by default; partial is fine.
struct PayBackSheet: View {
    let title: String
    let open: Centimes
    let action: (Centimes) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = AmountInput()

    var body: some View {
        let value = min(input.centimes, open)
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
            }
            ScreenTitle(text: title)
            AmountField(caption: L10n.t("Amount (%@ open)", Money.format(open)), text: input.display())
            Spacer(minLength: 0)
            KeypadView { input.press($0) }
            Button(L10n.t("Save")) {
                action(value)
                dismiss()
            }
            .buttonStyle(.pillPrimary)
            .disabled(value <= 0)
            .opacity(value > 0 ? 1 : 0.5)
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
        .onAppear { input = AmountInput(centimes: open) }
    }
}

/// Home card: "Owed to you 450 DH · You owe 80 DH".
struct FriendsCard: View {
    let owed: Centimes
    let owe: Centimes
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "person.2")
                    .font(.scaled(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Theme.Colors.canvas, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(owed > 0 ? L10n.t("%@ owed to you", Money.format(owed)) : L10n.t("You owe %@", Money.format(owe)))
                        .font(.scaled(size: 15, weight: .semibold))
                    Text(owed > 0 && owe > 0 ? L10n.t("You owe %@ · Friends", Money.format(owe)) : L10n.t("Friends and split bills"))
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.forward").font(.scaled(size: 13, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
            }
            .padding(12)
            .foregroundStyle(Theme.Colors.ink)
            .background(Theme.Colors.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.friends")
    }
}
