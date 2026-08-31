#if canImport(SwiftUI)
import SwiftUI

/// The partyswoop design system, mapped 1:1 from its tailwind.config.ts.
/// Editorial / print aesthetic: sharp corners, no shadows, warm paper ground,
/// terracotta "live" accent. Shared by the app and the Share Extension so the
/// capture modal and the app feel identical.
public enum Theme {

    // MARK: Colors
    public enum Palette {
        public static let paper     = Color(hex: "F6F5F1")
        public static let rule      = Color(hex: "E6E4DC")
        public static let live      = Color(hex: "A8512C")
        public static let ink       = Color(hex: "1C1C1A")
        public static let liveWash  = Color(hex: "F1E6E0")
        public static let overdue   = Color(hex: "A8302C")

        public static func ink(_ opacity: Double) -> Color { ink.opacity(opacity) }
    }

    // MARK: Spacing (8/16/24/40/64/104)
    public enum Space {
        public static let s1: CGFloat = 8
        public static let s2: CGFloat = 16
        public static let s3: CGFloat = 24
        public static let s4: CGFloat = 40
        public static let s5: CGFloat = 64
        public static let s6: CGFloat = 104
    }

    // MARK: Type
    // Zen Kaku Gothic New + DM Mono. When the fonts are bundled they're used by
    // name; otherwise these fall back gracefully to the system font.
    public enum Typeface {
        public static let zen = "Zen Kaku Gothic New"
        public static let mono = "DM Mono"
    }

    public enum Text {
        public static func display() -> Font { custom(Typeface.zen, 76, .black) }
        public static func h1() -> Font { custom(Typeface.zen, 42, .heavy) }
        public static func h2() -> Font { custom(Typeface.zen, 30, .bold) }
        public static func h3() -> Font { custom(Typeface.zen, 24, .bold) }
        public static func body() -> Font { custom(Typeface.zen, 16, .regular) }
        public static func list() -> Font { custom(Typeface.zen, 15, .regular) }
        public static func meta() -> Font { custom(Typeface.mono, 11, .regular) }

        private static func custom(_ name: String, _ size: CGFloat, _ weight: Font.Weight) -> Font {
            Font.custom(name, size: size).weight(weight)
        }
    }
}

public extension Color {
    /// Init from a 6-digit hex string (no alpha).
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

public extension Category {
    /// The category's accent color in the design system.
    var color: Color { Color(hex: colorHex) }
}
#endif
