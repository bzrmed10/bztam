import SwiftData
import SwiftUI
import UIKit

/// Check what was read before saving: the image, the total, the shop, the date and the category.
struct ScanReviewView: View {
    let draft: ScanDraft
    let onRetake: () -> Void
    var onDone: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<BudgetCategory> { !$0.isArchived }, sort: \BudgetCategory.order) private var categories: [BudgetCategory]

    @State private var amount = AmountInput()
    @State private var merchant = ""
    @State private var date = Date.now
    @State private var categoryID: UUID?
    @State private var suggested = false
    @State private var editingAmount = false
    @State private var showImage = false
    @State private var loaded = false

    private var canSave: Bool { amount.centimes > 0 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                    Spacer()
                }
                ScreenTitle(text: draft.source == .camera ? L10n.t("Check the receipt") : L10n.t("Check the bill"))

                if let image = draft.images.first {
                    Button { showImage = true } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .background(Theme.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.t("Show the full image"))
                }

                Button { editingAmount = true } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.receipt.amount == nil ? L10n.t("No total found. Tap to type it.") : L10n.t("Total found"))
                            .font(.bzCaption)
                            .foregroundStyle(draft.receipt.amount == nil ? Theme.Colors.negative : Theme.Colors.inkMuted)
                        HStack(alignment: .firstTextBaseline) {
                            Text(Money.format(amount.centimes))
                                .font(.bzAmountHero)
                                .tracking(-1.2)
                                .foregroundStyle(Theme.Colors.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Image(systemName: "pencil").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.Colors.inkMuted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("scan.total")

                VStack(spacing: 0) {
                    row(L10n.t("Shop")) {
                        TextField(L10n.t("Shop name"), text: $merchant)
                            .multilineTextAlignment(.trailing)
                            .font(.bzBodyStrong)
                    }
                    row(L10n.t("Date")) {
                        DatePicker("", selection: $date, in: ...Date.now, displayedComponents: .date)
                            .labelsHidden()
                    }
                    row(L10n.t("Category")) {
                        HStack(spacing: 8) {
                            if suggested {
                                Text(L10n.t("Suggested")).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                            }
                            Menu {
                                ForEach(categories) { c in
                                    Button(c.displayName) { categoryID = c.id; suggested = false }
                                }
                            } label: {
                                Text(categories.first(where: { $0.id == categoryID })?.displayName ?? L10n.t("Choose"))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .frame(height: 36)
                                    .background(Theme.Colors.ink, in: Capsule())
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    Button(L10n.t("Add expense")) { save() }
                        .buttonStyle(.pillPrimary)
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.5)
                        .accessibilityIdentifier("scan.save")
                    if draft.source == .camera || draft.source == .screenshot {
                        Button(draft.source == .camera ? L10n.t("Retake photo") : L10n.t("Choose another image")) {
                            dismiss()
                            onRetake()
                        }
                        .buttonStyle(.pillSecondary)
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.m)
            .foregroundStyle(Theme.Colors.ink)
        }
        .background(Theme.Colors.canvas)
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $editingAmount) {
            AmountEditSheet(title: L10n.t("Total"), input: $amount)
        }
        .fullScreenCover(isPresented: $showImage) {
            ImageViewer(image: draft.images.first)
        }
        .onAppear(perform: load)
        .onDisappear(perform: onDone)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).font(.system(size: 15)).foregroundStyle(Theme.Colors.inkMuted)
            Spacer(minLength: 16)
            content()
        }
        .frame(minHeight: 52)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let r = draft.receipt
        if let a = r.amount { amount = AmountInput(centimes: a) }
        merchant = r.merchant ?? ""
        if let d = r.date { date = d }
        if let key = r.categoryKey, let c = categories.first(where: { $0.key == key }) {
            categoryID = c.id
            suggested = true
        } else {
            categoryID = categories.first(where: { $0.key == "other" })?.id
        }
    }

    private func save() {
        guard canSave else { return }
        let category = categories.first(where: { $0.id == categoryID }) ?? categories.first(where: { $0.key == "other" })
        let entry = Entry(kind: .expense, amount: amount.centimes, date: date,
                          merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
                          category: category, source: draft.source)
        if let image = draft.images.first { entry.attachmentName = AttachmentStore.save(image) }
        context.insert(entry)
        try? context.save()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Type an amount with the keypad (used to fix a scanned total).
struct AmountEditSheet: View {
    let title: String
    @Binding var input: AmountInput
    @Environment(\.dismiss) private var dismiss
    @State private var working = AmountInput()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
                Spacer()
            }
            ScreenTitle(text: title)
            AmountField(caption: L10n.t("Amount"), text: working.display())
            Spacer(minLength: 0)
            KeypadView { working.press($0) }
            Button(L10n.t("Done")) {
                input = working
                dismiss()
            }
            .buttonStyle(.pillPrimary)
        }
        .padding(Theme.Space.l)
        .foregroundStyle(Theme.Colors.ink)
        .background(Theme.Colors.canvas)
        .presentationDetents([.large])
        .onAppear { working = input }
    }
}

/// Full-screen receipt image with pinch to zoom.
struct ImageViewer: View {
    let image: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(MagnifyGesture().onChanged { scale = max(1, min(4, $0.magnification)) }
                        .onEnded { _ in withAnimation(.snappy) { if scale < 1.1 { scale = 1 } } })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            CircleIconButton(symbol: "xmark", label: L10n.t("Close"), fill: .white) { dismiss() }
                .padding(Theme.Space.l)
        }
    }
}
