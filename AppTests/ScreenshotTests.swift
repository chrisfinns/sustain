import AppKit
import SustainCore
import SwiftData
import SwiftUI
import Testing
@testable import Sustain

/// Renders each screen with the mockup's sample data, dark and light, to PNGs for side-by-side checks against
/// the mockup boards. CI uploads them as the "screens" artifact. Video can't render offscreen, so the practice
/// shot uses an item without one.
@MainActor
struct ScreenshotTests {
    static var outputDir: URL {
        FileManager.default.temporaryDirectory.appending(path: "sustain-snapshots", directoryHint: .isDirectory)
    }

    @Test func renderScreens() throws {
        let container = try Store.makeContainer(inMemory: true)
        try SampleData.load(container.mainContext)
        let settings = AppSettings(defaults: UserDefaults(suiteName: "sustain.snapshots.\(UUID().uuidString)")!)
        let app = AppModel(container: container, settings: settings, media: nil)
        try FileManager.default.createDirectory(at: Self.outputDir, withIntermediateDirectories: true)

        let items = try container.mainContext.fetch(FetchDescriptor<Item>())
        let shots: [(String, () -> Void)] = [
            ("1-today", { app.screen = .today }),
            ("2-practice", { app.open("demo-penta", items: items) }),
            ("3-capture", { app.screen = .today; app.showCapture = true }),
            ("4-library", { app.showCapture = false; app.session = nil; app.screen = .library }),
            ("5-settings", { app.screen = .settings }),
        ]
        var written = 0
        for (name, setUp) in shots {
            setUp()
            for scheme in [ColorScheme.dark, .light] {
                let view = ContentView()
                    .themed()
                    .environment(\.colorScheme, scheme)
                    .environment(\.isSnapshot, true)
                    .environment(app)
                    .modelContainer(container)
                    .frame(width: 1440, height: name == "5-settings" ? 1800 : name == "1-today" || name == "4-library" ? 1100 : 900)
                let renderer = ImageRenderer(content: view)
                renderer.scale = 1
                guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                      let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                    Issue.record("couldn't render \(name)")
                    continue
                }
                let file = Self.outputDir.appending(path: "\(name)-\(scheme == .dark ? "dark" : "light").png")
                try png.write(to: file)
                written += 1
            }
        }
        print("Wrote \(written) screenshots to \(Self.outputDir.path)")
        #expect(written == shots.count * 2)
    }

    /// The Scales tab on its own: the practice card picks its tab on appear, which an offscreen render never runs.
    @Test func renderScalesPanel() throws {
        let container = try Store.makeContainer(inMemory: true)
        let settings = AppSettings(defaults: UserDefaults(suiteName: "sustain.snapshots.\(UUID().uuidString)")!)
        let app = AppModel(container: container, settings: settings, media: nil)
        try FileManager.default.createDirectory(at: Self.outputDir, withIntermediateDirectories: true)
        for scheme in [ColorScheme.dark, .light] {
            let view = ScalesPanel(player: ScalePlayer())
                .padding(24)
                .themed()
                .environment(\.colorScheme, scheme)
                .environment(\.isSnapshot, true)
                .environment(app)
                .frame(width: 760)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let png = try #require(renderer.nsImage?.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:]) })
            try png.write(to: Self.outputDir.appending(path: "6-scales-\(scheme == .dark ? "dark" : "light").png"))
        }
    }
}
