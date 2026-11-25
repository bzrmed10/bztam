import SwiftUI

/// A search field for long lists.
struct SearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.Colors.inkMuted)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.Colors.inkMuted)
                }
                .accessibilityLabel(L10n.t("Clear"))
            }
        }
        .font(.bzBody)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(Theme.Colors.surface, in: Capsule())
    }
}

/// Settings → Currency: every currency, the iPhone's region first, with search.
struct CurrencyPickerSheet: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let region = Currency.ofRegion
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.t("Currency")).font(.scaled(size: 22, weight: .heavy))
                Spacer()
                CircleIconButton(symbol: "xmark", label: L10n.t("Close")) { dismiss() }
            }
            Text(L10n.t("Amounts aren't converted: only the currency shown changes."))
                .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
            SearchField(placeholder: L10n.t("Search currencies"), text: $query)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Currency.sorted(region: region).filter { $0.matches(query) }) { c in
                        CurrencyRow(currency: c, isRegion: c == region, selected: selection == c.rawValue) {
                            selection = c.rawValue
                            dismiss()
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .padding(Theme.Space.l)
        .background(Theme.Colors.canvas)
        .foregroundStyle(Theme.Colors.ink)
        .presentationDetents([.large])
    }
}

struct CurrencyRow: View {
    let currency: Currency
    let isRegion: Bool
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(currency.symbol)
                    .font(.scaled(size: 14, weight: .heavy))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .frame(width: 44, height: 44)
                    .background(selected ? Theme.Colors.brand : Theme.Colors.canvas, in: Circle())
                    .foregroundStyle(selected ? Theme.Colors.onBrand : Theme.Colors.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name).font(.bzBodyStrong)
                    Text(isRegion ? currency.code + " · " + L10n.t("Your iPhone's region") : currency.code)
                        .font(.bzCaption).foregroundStyle(Theme.Colors.inkMuted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.scaled(size: 22)).foregroundStyle(Theme.Colors.positive)
                }
            }
            .padding(10)
            .background(Theme.Colors.surface.opacity(selected ? 1 : 0.5), in: RoundedRectangle(cornerRadius: Theme.Radius.small))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.small).stroke(selected ? Theme.Colors.ink : .clear, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .foregroundStyle(Theme.Colors.ink)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("currency.\(currency.rawValue)")
    }
}
