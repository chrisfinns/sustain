import SwiftUI
import SustainCore

extension Color {
    nonisolated init(_ c: RGBA) {
        self.init(.sRGB, red: Double(c.r) / 255, green: Double(c.g) / 255, blue: Double(c.b) / 255, opacity: c.a)
    }
}

/// Paper & Ink tokens for the current light/dark mode. Names match the mockup.
nonisolated struct Theme: Sendable {
    let tokens: ThemeTokens

    subscript(_ token: Token) -> Color { Color(tokens[token]) }
    func color(_ name: ColorName) -> Color { Color(tokens.color(name)) }
    func rating(_ r: Rating) -> Color { Color(tokens.rating(r)) }
    func ratingLine(_ r: Rating) -> Color { Color(tokens.ratingLine(r)) }

    static let dark = Theme(tokens: PaperAndInk.darkTokens)
    static let light = Theme(tokens: PaperAndInk.lightTokens)
}

extension EnvironmentValues {
    @Entry var theme: Theme = .dark
    /// True when rendering screenshots offscreen: scroll views are replaced by plain stacks.
    @Entry var isSnapshot = false
}

private struct Themed: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let theme: Theme = scheme == .dark ? .dark : .light
        content
            .environment(\.theme, theme)
            .tint(theme[.accent])
            .foregroundStyle(theme[.text])
            .background(theme[.bg])
    }
}

extension View {
    /// Resolves the theme from the window's color scheme.
    func themed() -> some View { modifier(Themed()) }
}

/// Type scale from the mockup.
nonisolated enum Typo {
    static let pageTitle = Font.system(size: 32, weight: .bold)
    static let practiceTitle = Font.system(size: 26, weight: .bold)
    static let modalTitle = Font.system(size: 20, weight: .bold)
    static let sectionTitle = Font.system(size: 17, weight: .bold)
    static let rowTitle = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 14)
    static let meta = Font.system(size: 13)
    static let small = Font.system(size: 12)
    static let label = Font.system(size: 11, weight: .semibold)
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// "WARM-UP" style section label: 11pt semibold, uppercase, 0.12em tracking, faint.
struct SectionLabel: View {
    @Environment(\.theme) private var theme
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Typo.label)
            .tracking(11 * 0.12)
            .foregroundStyle(theme[.faint])
    }
}
