import SwiftUI
import UIKit

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
        static let primaryText = Color("BrandPrimaryText")
        static let primaryPressed = Color("BrandPrimaryPressed")
        static let primaryMuted = Color("BrandPrimaryMuted")
        static let primaryForeground = Color("BrandPrimaryForeground")
        static let secondary = Color("SecondaryFill")
        static let success = Color("Success")
        static let warning = Color("Warning")
        static let destructive = Color("Destructive")
        static let info = Color("Info")
        static let cameraBackdrop = Color("CameraBackdrop")
        static let shadow = Color(hex: 0x000000)
        static let pearlIvory = Color.dynamic(light: 0xFFFDF8, dark: 0x1B1816)
        static let pearlMist = Color.dynamic(light: 0xF2F6FF, dark: 0x171A22)
        static let pearlPeach = Color.dynamic(light: 0xFFEAD8, dark: 0x2D1B12)
        static let pearlRose = Color.dynamic(light: 0xFFE7EF, dark: 0x29171D)
        static let pearlSky = Color.dynamic(light: 0xEAF6FF, dark: 0x121F2A)
        static let pearlChampagne = Color.dynamic(light: 0xF8E7C6, dark: 0x261D12)
        static let platformEbay = Color(hex: 0x0064D2)
        static let platformMercari = Color(hex: 0xE60023)
        static let platformPoshmark = Color(hex: 0xE51A72)
        static let platformFacebook = Color(hex: 0x1877F2)
        static let platformOfferUp = Color(hex: 0x16A34A)
        static let platformCraigslist = Color(hex: 0x6B21A8)
        static let platformDepop = Color(hex: 0xE11D48)
        static let platformWhatnot = Color(hex: 0xFF5722)
        static let platformEtsy = Color(hex: 0xF1641E)
        static let platformStockX = Color(hex: 0x006340)
        static let platformGrailed = Color(hex: 0x000000)
        static let platformReverb = Color(hex: 0xF5A623)
        static let platformVinted = Color(hex: 0x09B1BA)
        static let platformNextdoor = Color(hex: 0x00B246)
        static let platformAmazon = Color(hex: 0xFF9900)
        static let platformGOAT = Color(hex: 0x111111)
        static let platformKidizen = Color(hex: 0x13A8A8)
        static let platformVestiaire = Color(hex: 0x6B4F3F)
        static let platformTheRealReal = Color(hex: 0x111827)
        static let platformSwappa = Color(hex: 0x2E7D32)
        static let platformTradesy = Color(hex: 0xB83280)
        static let platformChairish = Color(hex: 0xC75D2C)
        static let platformBonanza = Color(hex: 0x2B6CB0)
        static let platformCurtsy = Color(hex: 0xF97316)
        static let platformShopify = Color(hex: 0x95BF47)
        static let platformRubyLane = Color(hex: 0x8B0000)
        static let platformTCGplayer = Color(hex: 0x0F766E)
        static let launchBackground = Color(hex: 0xFFFFFF)
        static let launchForeground = Color(hex: 0x121212)
        static let launchPrimary = Color(hex: 0xFF7A26)

        enum AccessibilityBorderToken: Equatable {
            case standard
            case strong
        }

        static func accessibilityBorderToken(differentiateWithoutColor: Bool) -> AccessibilityBorderToken {
            differentiateWithoutColor ? .strong : .standard
        }

        static func accessibilityBorder(differentiateWithoutColor: Bool) -> Color {
            switch accessibilityBorderToken(differentiateWithoutColor: differentiateWithoutColor) {
            case .standard:
                border
            case .strong:
                borderStrong
            }
        }
    }

    init(hex: UInt, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
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
    static func raised(color: Color = Color.brand.shadow) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.04), radius: 6, y: 2)
    }

    static func hover(color: Color = Color.brand.shadow) -> some ViewModifier {
        ShadowModifier(color: color.opacity(0.06), radius: 16, y: 6)
    }

    static func elevated(color: Color = Color.brand.shadow) -> some ViewModifier {
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
    static let screen = Animation.easeOut(duration: 0.2)
    static let quick = Animation.easeOut(duration: 0.15)

    static func shouldReduceMotion(os: Bool, app: Bool) -> Bool {
        os || app
    }

    static func animation(reduceMotion: Bool) -> Animation {
        reduceMotion ? quick : spring
    }

    static func screenAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? quick : screen
    }

    static func screenTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8))
    }

    static func toastTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
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
