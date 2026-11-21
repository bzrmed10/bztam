import SwiftUI
import UIKit

/// Closes whatever keyboard is open.
@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

/// A small "Done" button that floats just above the keyboard while it is open, so number pads
/// (which have no return key) can always be closed.
struct KeyboardDoneButton: ViewModifier {
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if visible {
                    Button(action: hideKeyboard) {
                        HStack(spacing: 6) {
                            Image(systemName: "keyboard.chevron.compact.down")
                            Text(L10n.t("Done"))
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Colors.ink)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Theme.Colors.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 12)
                    .padding(.bottom, 8)
                    .accessibilityLabel(L10n.t("Hide keyboard"))
                    .accessibilityIdentifier("keyboard.done")
                    .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .bottomTrailing)))
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.snappy) { visible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.snappy) { visible = false }
            }
    }
}

extension View {
    /// Adds the floating "Done" button above the keyboard.
    func keyboardDoneButton() -> some View { modifier(KeyboardDoneButton()) }
}

/// A whole-amount text field that shows the currency and groups thousands while you type: "3 000 DH".
/// Empty means no amount (no "0" to delete first).
struct MoneyTextField: View {
    @Binding var value: Centimes
    var placeholder: String = ""
    var font: Font = .system(size: 17, weight: .bold).monospacedDigit()
    var width: CGFloat? = 120
    var accessibility: String = ""

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        let symbolFirst = Money.currency.symbolFirst(language: L10n.code)
        HStack(spacing: 4) {
            if symbolFirst { symbol }
            TextField(placeholder, text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(font)
                .focused($focused)
                .accessibilityLabel(accessibility)
                .onChange(of: text) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(AmountInput.maxUnitsDigits))
                    let units = Int(digits) ?? 0
                    value = units * 100
                    let shown = digits.isEmpty ? "" : Money.format(units * 100, symbol: false, privacy: .never)
                        .replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2069}", with: "")
                    if shown != new { text = shown }
                }
            if !symbolFirst { symbol }
        }
        .padding(.horizontal, 14)
        .frame(width: width, height: 44)
        .background(Theme.Colors.canvas, in: Capsule())
        .overlay(Capsule().stroke(focused ? Theme.Colors.ink : Theme.Colors.line, lineWidth: focused ? 1.5 : 1))
        .contentShape(Capsule())
        .onTapGesture { focused = true }
        .environment(\.layoutDirection, .leftToRight)
        .onAppear {
            if value > 0 && text.isEmpty {
                text = Money.format(value / 100 * 100, symbol: false, privacy: .never)
                    .replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2069}", with: "")
            }
        }
        .onChange(of: value) { _, new in
            // Changed from outside (a new suggestion): show it.
            if !focused {
                text = new > 0 ? Money.format(new / 100 * 100, symbol: false, privacy: .never)
                    .replacingOccurrences(of: "\u{2066}", with: "").replacingOccurrences(of: "\u{2069}", with: "") : ""
            }
        }
    }

    private var symbol: some View {
        Text(Money.currencySymbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.Colors.inkMuted)
            .fixedSize()
    }
}
