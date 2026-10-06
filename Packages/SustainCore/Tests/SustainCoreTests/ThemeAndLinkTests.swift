import Foundation
import Testing
@testable import SustainCore

@Suite struct ThemeTests {
    struct Fixture: Decodable {
        struct Mode: Decodable {
            let tokens: [String: String]
            let data: [String: String]
        }

        let dark: Mode
        let light: Mode
    }

    @Test(arguments: ThemeMode.allCases)
    func matchesTheMockupsBuildTheme(mode: ThemeMode) throws {
        let fx = try JSONDecoder().decode(Fixture.self, from: try fixture("theme-paper"))
        let want = mode == .dark ? fx.dark : fx.light
        let got = PaperAndInk.tokens(mode)
        #expect(want.tokens.count == Token.allCases.count)
        for (name, css) in want.tokens {
            let token = try #require(Token(rawValue: name), "unknown token \(name)")
            #expect(got[token] == RGBA(css), "\(mode) \(name): got \(got[token].hex), want \(css)")
        }
        for (name, css) in want.data {
            let c = try #require(ColorName(rawValue: name))
            #expect(got.color(c) == RGBA(css))
        }
    }

    /// The contrast gate from design/mockup/checks/contrast.js, for Paper & Ink.
    @Test(arguments: ThemeMode.allCases)
    func passesTheContrastGate(mode: ThemeMode) {
        let t = PaperAndInk.tokens(mode)
        var fails: [String] = []
        func need(_ fg: Token, _ bgs: [Token], _ min: Double) {
            for bg in bgs where t[fg].contrast(t[bg]) < min {
                fails.append("\(fg) on \(bg) = \(t[fg].contrast(t[bg]))")
            }
        }
        need(.text, [.bg], 7)
        need(.text, [.surf, .surf2, .surf3, .raised2, .sel3, .side], 4.5)
        need(.textSoft, [.surf], 7)
        need(.muted, [.bg, .dim, .side, .surf, .surf2, .surf3, .raised, .raised2, .sel, .sel2, .sel3, .accentTint], 4.5)
        need(.faint, [.bg, .dim, .side, .surf, .surf2, .surf3, .raised2], 4.5)
        need(.onAccent, [.accent], 4.5)
        need(.accent, [.bg, .surf, .surf2, .accentTint, .accentTint2, .sel3], 4.5)
        need(.again, [.surf, .surf2, .raised, .againTint, .againTint2], 4.5)
        need(.hard, [.surf, .surf2, .raised], 4.5)
        need(.good, [.surf, .surf2, .raised, .goodTint], 4.5)
        need(.easy, [.surf, .surf2, .raised, .easyTint], 4.5)
        need(.violet, [.violetTint, .surf2], 4.5)
        need(.bg, [.text], 7)
        need(.vidText, [.vid], 4.5)
        need(.paperMuted, [.paper], 4.5)
        need(.paperInk, [.paper], 7)
        need(.line3, [.surf], 1.25)
        for c in ColorName.allCases {
            for bg in [Token.surf2, .bg] where t.color(c).contrast(t[bg]) < 3 {
                fails.append("data \(c) on \(bg)")
            }
        }
        #expect(fails.isEmpty, "\(fails)")
    }

    @Test func rgbaParsesAndPrints() {
        #expect(RGBA("#1A1917").hex == "#1A1917")
        #expect(RGBA("rgba(8,8,10,0.74)") == RGBA(r: 8, g: 8, b: 10, a: 0.74))
        #expect(RGBA("#000000").mix(RGBA("#FFFFFF"), 0.5).hex == "#808080")
        #expect(ColorName.leastUsed([.amber, .coral]) == .rose)
        #expect(ColorName.slate.next == .amber)
    }
}

@Suite struct LinkTests {
    @Test(arguments: [
        "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        "youtube.com/watch?v=dQw4w9WgXcQ&list=PL123",
        "https://youtu.be/dQw4w9WgXcQ?t=42",
        "https://youtube.com/shorts/dQw4w9WgXcQ",
        "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
        "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
        "https://www.youtube.com/live/dQw4w9WgXcQ?si=abc",
        "dQw4w9WgXcQ",
    ])
    func findsTheVideoId(url: String) {
        #expect(YouTubeLink.videoId(url) == "dQw4w9WgXcQ")
    }

    @Test(arguments: ["https://vimeo.com/123456", "https://youtube.com/watch?v=short", "not a link", ""])
    func rejectsOtherLinks(url: String) {
        #expect(YouTubeLink.videoId(url) == nil)
    }

    @Test func startTimes() {
        #expect(YouTubeLink.startSeconds("https://youtu.be/dQw4w9WgXcQ?t=90") == 90)
        #expect(YouTubeLink.startSeconds("https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1m30s") == 90)
        #expect(YouTubeLink.startSeconds("https://www.youtube.com/embed/dQw4w9WgXcQ?start=5") == 5)
        #expect(YouTubeLink.startSeconds("https://www.youtube.com/watch?v=dQw4w9WgXcQ") == nil)
        #expect(YouTubeLink.formatTime(83.4) == "1:23")
        #expect(YouTubeLink.formatTime(nil) == "—")
        #expect(formatClock(872) == "14:32")
    }

    @Test func detectsLinkKinds() {
        #expect(LinkDetect.detect("https://youtu.be/dQw4w9WgXcQ") == .youtube)
        #expect(LinkDetect.detect("https://example.com/tab.PDF?dl=1") == .pdf)
        #expect(LinkDetect.detect("https://example.com/lesson") == .link)
        #expect(LinkDetect.detect("hello") == nil)
        #expect(LinkDetect.detect("") == nil)
    }
}
