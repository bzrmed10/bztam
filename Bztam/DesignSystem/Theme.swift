import SwiftUI
import UIKit

/// Design tokens from the "Bztam" design system (Wise-style: flat surfaces, big bold type,
/// one lime action per screen, forest-green text). Every color, size and radius in the app comes from here.
/// Each color has a light and a dark value; dark mode is a deep forest night with the same lime.
enum Theme {
    enum Colors {
        /// Page background. Content sits directly on it.
        static let canvas = Color.dynamic(0xFFFFFF, 0x0F140D)
        /// The one neutral fill: icon circles, inputs, chips, secondary buttons, progress tracks.
        static let surface = Color.dynamic(0xEEF2EA, 0x1D261A)
        /// Hairline dividers and input borders.
        static let line = Color.dynamic(0xDDE5D6, 0x2C3828)
        /// All primary text and amounts, selected chips, progress fills.
        static let ink = Color.dynamic(0x14290B, 0xE9F2E3)
        /// Secondary text.
        static let inkMuted = Color.dynamic(0x586452, 0x9DAA95)
        /// Bright lime: the one main action per screen, the active tab. Always with `onBrand` on top.
        static let brand = Color(hex: 0xA6E36F)
        /// Text and icons on lime: forest green in both modes.
        static let onBrand = Color(hex: 0x14290B)
        /// Text and icons on an `ink` fill (selected chips).
        static let onInk = Color.dynamic(0xFFFFFF, 0x0F140D)
        /// Soft lime: soft highlights, money-in icon circles.
        static let brandTint = Color.dynamic(0xE3F5D2, 0x22351A)
        /// Text links and text buttons.
        static let link = Color.dynamic(0x2F6B12, 0xB5E68A)
        /// Money in and "Paid" only.
        static let positive = Color.dynamic(0x2F7A2B, 0x7ED37A)
        /// Over budget only, always with words.
        static let negative = Color.dynamic(0xB3261E, 0xFF8A80)
        /// The undo toast: dark in both modes, a step lighter than the page at night.
        static let toast = Color.dynamic(0x14290B, 0x2A3A22)
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 40
    }

    enum Radius {
        static let small: CGFloat = 12
        static let large: CGFloat = 28
    }

    enum Size {
        static let iconCircle: CGFloat = 48
        static let quickAction: CGFloat = 56
        static let button: CGFloat = 56
        static let row: CGFloat = 64
    }
}

/// Type styles. SF Pro with tabular figures for amounts.
extension Font {
    static let bzAmountHero = Font.system(size: 48, weight: .heavy).monospacedDigit()
    static let bzTitleXL = Font.system(size: 32, weight: .heavy)
    static let bzTitle = Font.system(size: 20, weight: .bold)
    static let bzBodyStrong = Font.system(size: 16, weight: .semibold)
    static let bzBody = Font.system(size: 16, weight: .regular)
    static let bzCaption = Font.system(size: 13, weight: .medium)
    static let bzAmount = Font.system(size: 16, weight: .semibold).monospacedDigit()
}

extension Color {
    /// A color that follows light and dark mode.
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// Settings → Appearance. `-appearance dark` sets it from a launch argument (screenshots).
enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    static let storageKey = "appearance"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.t("Automatic")
        case .light: L10n.t("Light")
        case .dark: L10n.t("Dark")
        }
    }

    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
