import SwiftUI

extension Color {
    enum brand {
        static let background = Color("Background")
        static let backgroundSubtle = Color("BackgroundSubtle")
        static let surface = Color("Surface")
        static let surfaceElevated = Color("SurfaceElevated")
        static let foreground = Color("Foreground")
        static let foregroundSecondary = Color("ForegroundSecondary")
        static let mutedForeground = Color("MutedForeground")
        static let border = Color("Border")
        static let borderStrong = Color("BorderStrong")
        static let primary = Color("BrandPrimary")
        static let primaryPressed = Color("BrandPrimaryPressed")
        static let primaryMuted = Color("BrandPrimaryMuted")
        static let primaryForeground = Color("BrandPrimaryForeground")
        static let secondary = Color("SecondaryFill")
        static let success = Color("Success")
        static let warning = Color("Warning")
        static let destructive = Color("Destructive")
        static let info = Color("Info")
    }

    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

enum Radius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let pill: CGFloat = 999
}

enum AppShadow {
    static func raised(color: Color = .black) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.04), radius: 6, y: 2)
    }

    static func hover(color: Color = .black) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.06), radius: 16, y: 6)
    }

    static func elevated(color: Color = .black) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.08), radius: 40, y: 16)
    }
}

private struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: 0, y: y)
    }
}

enum AppMotion {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let sheet = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let quick = Animation.easeOut(duration: 0.15)

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? quick : spring
    }
}

private struct AppReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appReduceMotion: Bool {
        get { self[AppReduceMotionKey.self] }
        set { self[AppReduceMotionKey.self] = newValue }
    }
}

extension View {
    func brandScreenBackground() -> some View {
        background(Color.brand.background.ignoresSafeArea())
    }

    func dynamicTypeLimit() -> some View {
        dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }
}
