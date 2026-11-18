import SwiftUI

/// The 3×4 amount keypad: digits, decimal comma and delete.
struct KeypadView: View {
    let onKey: (String) -> Void

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", ",", "0", "⌫"]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Button {
                    onKey(key)
                } label: {
                    Group {
                        if key == "⌫" {
                            Image(systemName: "delete.left").font(.system(size: 22, weight: .medium))
                        } else {
                            Text(key == "," ? (L10n.code == "fr" ? "," : ".") : key)
                                .font(.system(size: 24, weight: .semibold))
                        }
                    }
                    .foregroundStyle(Theme.Colors.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(KeyButtonStyle())
                .accessibilityLabel(key == "⌫" ? L10n.t("Delete") : (key == "," ? L10n.t("Decimal") : key))
            }
        }
    }
}

private struct KeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Theme.Colors.surface : Color.clear,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.small))
    }
}

/// Two-option pill switch (Expense / Money in).
struct SegmentedPill<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.0) { option in
                let on = option.0 == selection
                Button {
                    selection = option.0
                } label: {
                    Text(option.1)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(on ? Color.white : Theme.Colors.inkMuted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(on ? Theme.Colors.ink : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.Colors.surface, in: Capsule())
    }
}

/// Wraps children onto new lines (chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// Amount box: caption, big typed amount, currency pill.
struct AmountField: View {
    let caption: String
    let text: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(caption).font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                Text(text)
                    .font(.system(size: 40, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.Colors.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Spacer()
            Text(Money.currencySymbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.Colors.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Theme.Colors.surface, in: Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(Theme.Colors.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
