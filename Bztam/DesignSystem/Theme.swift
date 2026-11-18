import SwiftUI

/// Design tokens from the "Bztam" design system (Wise-style: flat white, big bold type,
/// one lime action per screen, forest-green text). Every color, size and radius in the app comes from here.
enum Theme {
    enum Colors {
        /// Page background. Content sits directly on it.
        static let canvas = Color(hex: 0xFFFFFF)
        /// The one neutral fill: icon circles, inputs, chips, secondary buttons, progress tracks.
        static let surface = Color(hex: 0xEEF2EA)
        /// Hairline dividers and input borders.
        static let line = Color(hex: 0xDDE5D6)
        /// All primary text and amounts, selected chips, progress fills.
        static let ink = Color(hex: 0x14290B)
        /// Secondary text.
        static let inkMuted = Color(hex: 0x586452)
        /// Bright lime: the one main action per screen, the active tab. Always with `ink` on top.
        static let brand = Color(hex: 0xA6E36F)
        /// Soft lime: soft highlights, money-in icon circles.
        static let brandTint = Color(hex: 0xE3F5D2)
        /// Text links and text buttons.
        static let link = Color(hex: 0x2F6B12)
        /// Money in and "Paid" only.
        static let positive = Color(hex: 0x2F7A2B)
        /// Over budget only, always with words.
        static let negative = Color(hex: 0xB3261E)
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
