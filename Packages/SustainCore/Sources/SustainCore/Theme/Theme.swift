import Foundation

public enum ThemeMode: String, Sendable, CaseIterable {
    case dark, light
}

/// The user's Appearance setting.
public enum ModeSetting: String, Codable, Sendable, CaseIterable {
    case system, dark, light
}

/// An sRGB color with alpha. Parses "#RRGGBB" and "rgba(r,g,b,a)".
public struct RGBA: Sendable, Equatable, Hashable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8
    public var a: Double

    public init(r: UInt8, g: UInt8, b: UInt8, a: Double = 1) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init(_ css: String) {
        let s = css.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") {
            let v = UInt32(s.dropFirst(), radix: 16) ?? 0
            self.init(r: UInt8((v >> 16) & 0xFF), g: UInt8((v >> 8) & 0xFF), b: UInt8(v & 0xFF))
        } else {
            let inner = s.drop(while: { $0 != "(" }).dropFirst().prefix(while: { $0 != ")" })
            let parts = inner.split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            self.init(r: UInt8(parts.count > 0 ? parts[0] : 0), g: UInt8(parts.count > 1 ? parts[1] : 0),
                      b: UInt8(parts.count > 2 ? parts[2] : 0), a: parts.count > 3 ? parts[3] : 1)
        }
    }

    public var hex: String {
        let digits = Array("0123456789ABCDEF")
        return "#" + [r, g, b].map { String([digits[Int($0 >> 4)], digits[Int($0 & 0xF)]]) }.joined()
    }

    /// Channel mix toward `other` by `t`, rounded like the mockup (JavaScript Math.round).
    public func mix(_ other: RGBA, _ t: Double) -> RGBA {
        func ch(_ a: UInt8, _ b: UInt8) -> UInt8 { UInt8(jsRound(Double(a) + (Double(b) - Double(a)) * t)) }
        return RGBA(r: ch(r, other.r), g: ch(g, other.g), b: ch(b, other.b))
    }

    /// WCAG relative luminance.
    public var luminance: Double {
        func lin(_ c: UInt8) -> Double {
            let v = Double(c) / 255
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    public func contrast(_ other: RGBA) -> Double {
        let (x, y) = (max(luminance, other.luminance), min(luminance, other.luminance))
        return (x + 0.05) / (y + 0.05)
    }
}

/// Token names from the mockup's buildTheme.
public enum Token: String, Sendable, CaseIterable {
    case bg, text, accent, onAccent
    case dim, side, surf, surf2, surf3, raised, raised2, track, sideLine, sel, sel2, sel3
    case line, line2, line3, line4, line5, line6
    case disabled, disabled2, faint, muted, textSoft
    case accentTint, accentTint2, accentLine, heat1, heat2, onAccentLine
    case again, hard, good, easy, violet
    case againLine, hardLine, goodLine, easyLine
    case againTint, againTint2, goodTint, easyTint, violetTint
    case overlay, shadow
    case vid, vidLine, vidText, paper, paperInk, paperLine, paperMuted
}

public struct ThemeTokens: Sendable {
    public let mode: ThemeMode
    public let values: [Token: RGBA]
    /// Area and instrument colors for this mode.
    public let data: [ColorName: RGBA]

    public subscript(_ token: Token) -> RGBA { values[token]! }
    public func color(_ name: ColorName) -> RGBA { data[name]! }

    public func rating(_ r: Rating) -> RGBA {
        switch r {
        case .again: self[.again]
        case .hard: self[.hard]
        case .good: self[.good]
        case .easy: self[.easy]
        }
    }

    public func ratingLine(_ r: Rating) -> RGBA {
        switch r {
        case .again: self[.againLine]
        case .hard: self[.hardLine]
        case .good: self[.goodLine]
        case .easy: self[.easyLine]
        }
    }
}

/// Paper & Ink, the chosen scheme. Only these base colors are hand-picked; everything else is derived.
public enum PaperAndInk {
    struct Base {
        let bg, text, accent, onAccent, again, hard, good, easy, violet: String
    }

    static let dark = Base(bg: "#1A1917", text: "#EDE6D6", accent: "#E8876D", onAccent: "#1A0A05",
                           again: "#E8806E", hard: "#E2B65A", good: "#86A8F0", easy: "#6CC4A4", violet: "#B9A5EE")
    static let light = Base(bg: "#F5F1E8", text: "#1D1C1A", accent: "#A9412A", onAccent: "#FFFFFF",
                            again: "#B23A2E", hard: "#835C00", good: "#2D54C4", easy: "#1A715A", violet: "#6644C2")

    static let darkData: [ColorName: String] = [.amber: "#F0A73A", .coral: "#FF8170", .rose: "#F27FB2", .violet: "#B595FF",
                                                .blue: "#7AAEFF", .teal: "#5FD3B5", .green: "#9BD46A", .slate: "#9AA3B2"]
    static let lightData: [ColorName: String] = [.amber: "#A86400", .coral: "#C9452F", .rose: "#B83F78", .violet: "#6F4BCF",
                                                 .blue: "#2D5FC8", .teal: "#0F7F69", .green: "#4A7F1F", .slate: "#5A6474"]

    public static let darkTokens = build(.dark)
    public static let lightTokens = build(.light)

    public static func tokens(_ mode: ThemeMode) -> ThemeTokens {
        mode == .dark ? darkTokens : lightTokens
    }

    /// Same math as the mockup's buildTheme(dir, mode).
    public static func build(_ mode: ThemeMode) -> ThemeTokens {
        let dark = mode == .dark
        let b = dark ? Self.dark : Self.light
        let bg = RGBA(b.bg), text = RGBA(b.text), white = RGBA("#FFFFFF")
        let up = { (d: Double, l: Double) in bg.mix(text, dark ? d : l) }
        let card = { (d: Double, l: Double) in dark ? bg.mix(text, d) : bg.mix(white, l) }
        let tint = { (c: String, d: Double, l: Double) in dark ? bg.mix(RGBA(c), d) : white.mix(RGBA(c), l) }
        let v: [Token: RGBA] = [
            .bg: bg, .text: text, .accent: RGBA(b.accent), .onAccent: RGBA(b.onAccent),
            .dim: up(0.018, 0.025), .side: up(0.023, 0.03),
            .surf: card(0.032, 0.6), .surf2: card(0.041, 0.75), .surf3: card(0.05, 0.5),
            .raised: up(0.064, 0.05), .raised2: up(0.078, 0.065), .track: up(0.082, 0.08), .sideLine: up(0.087, 0.1),
            .sel: up(0.091, 0.06), .sel2: up(0.114, 0.075), .sel3: up(0.115, 0.07),
            .line: up(0.096, 0.11), .line2: up(0.114, 0.13), .line3: up(0.132, 0.15), .line4: up(0.155, 0.18),
            .line5: up(0.187, 0.23), .line6: up(0.26, 0.32),
            .disabled: up(0.31, 0.4), .disabled2: up(0.4, 0.46),
            .faint: up(0.585, 0.68), .muted: up(0.7, 0.77), .textSoft: up(0.92, 0.9),
            .accentTint: tint(b.accent, 0.12, 0.1), .accentTint2: tint(b.accent, 0.18, 0.14), .accentLine: tint(b.accent, 0.16, 0.35),
            .heat1: tint(b.accent, 0.3, 0.3), .heat2: tint(b.accent, 0.6, 0.62),
            .onAccentLine: RGBA(b.accent).mix(RGBA(b.onAccent), 0.35),
            .again: RGBA(b.again), .hard: RGBA(b.hard), .good: RGBA(b.good), .easy: RGBA(b.easy), .violet: RGBA(b.violet),
            .againLine: tint(b.again, 0.35, 0.45), .hardLine: tint(b.hard, 0.35, 0.45),
            .goodLine: tint(b.good, 0.35, 0.45), .easyLine: tint(b.easy, 0.35, 0.45),
            .againTint: tint(b.again, 0.17, 0.1), .againTint2: tint(b.again, 0.11, 0.07),
            .goodTint: tint(b.good, 0.15, 0.1), .easyTint: tint(b.easy, 0.15, 0.1), .violetTint: tint(b.violet, 0.15, 0.1),
            .overlay: dark ? RGBA(r: 8, g: 8, b: 10, a: 0.74) : RGBA(r: 30, g: 28, b: 24, a: 0.42),
            .shadow: dark ? RGBA(r: 0, g: 0, b: 0, a: 0.5) : RGBA(r: 30, g: 28, b: 24, a: 0.18),
            // A video player stays black and a PDF page stays paper in both modes.
            .vid: RGBA("#0B0B0D"), .vidLine: RGBA("#26262B"), .vidText: RGBA("#A9A59D"),
            .paper: RGBA("#F3F0E9"), .paperInk: RGBA("#1A1A1E"), .paperLine: RGBA("#9C978D"), .paperMuted: RGBA("#55514A"),
        ]
        let data = (dark ? darkData : lightData).mapValues { RGBA($0) }
        return ThemeTokens(mode: mode, values: v, data: data)
    }
}
