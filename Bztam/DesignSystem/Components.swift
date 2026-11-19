import SwiftUI

/// Full-width pill button. `.primary` is the one lime action of a screen, `.secondary` the soft one.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(kind == .primary ? Theme.Colors.onBrand : Theme.Colors.ink)
            .frame(maxWidth: .infinity, minHeight: Theme.Size.button)
            .background(kind == .primary ? Theme.Colors.brand : Theme.Colors.surface, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pillPrimary: PillButtonStyle { PillButtonStyle(kind: .primary) }
    static var pillSecondary: PillButtonStyle { PillButtonStyle(kind: .secondary) }
}

/// Round icon used at the start of every list row.
struct IconCircle: View {
    let symbol: String
    var size: CGFloat = Theme.Size.iconCircle
    var fill: Color = Theme.Colors.surface
    var tint: Color = Theme.Colors.ink

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(fill, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Round letter avatar (first letter of a shop).
struct LetterCircle: View {
    let text: String
    var size: CGFloat = Theme.Size.iconCircle

    var body: some View {
        Text(String(text.prefix(1)).uppercased())
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Theme.Colors.ink)
            .frame(width: size, height: size)
            .background(Theme.Colors.surface, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Thin pill progress bar. `value` is clamped to 0...1.
struct ProgressPill: View {
    var value: Double
    var height: CGFloat = 8
    var fill: Color = Theme.Colors.ink

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Colors.surface)
                Capsule()
                    .fill(fill)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Selectable pill chip (categories, filters).
struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? Theme.Colors.onInk : Theme.Colors.ink)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(selected ? Theme.Colors.ink : Theme.Colors.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Round 44pt icon button (back, close, settings).
struct CircleIconButton: View {
    let symbol: String
    let label: String
    var fill: Color = Theme.Colors.surface
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.Colors.ink)
                .frame(width: 44, height: 44)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Small rounded pill label ("1,500 DH not planned").
struct TagPill: View {
    let text: String
    var fill: Color = Theme.Colors.brandTint

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.Colors.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(fill, in: Capsule())
    }
}

/// Big screen title (32pt heavy, left aligned).
struct ScreenTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.bzTitleXL)
            .tracking(-0.6)
            .foregroundStyle(Theme.Colors.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Section heading (20pt bold).
struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.bzTitle)
            .foregroundStyle(Theme.Colors.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Centered empty state with an icon circle and two lines.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            IconCircle(symbol: symbol, size: 64)
            Text(title).font(.bzBodyStrong).foregroundStyle(Theme.Colors.ink)
            Text(message)
                .font(.bzCaption)
                .foregroundStyle(Theme.Colors.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xl)
    }
}
