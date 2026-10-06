import AppKit
import Combine
import SwiftData
import SwiftUI

@main
struct SustainApp: App {
    @State private var app: AppModel

    init() {
        // UI tests run against a fresh in-memory store and their own settings.
        let uiTest = CommandLine.arguments.contains("-uitest")
        let container: ModelContainer
        do {
            container = try Store.makeContainer(inMemory: uiTest)
        } catch {
            fatalError("Sustain couldn't open its data store: \(error)")
        }
        try? Seeder.run(container.mainContext)
        let defaults = uiTest ? UserDefaults(suiteName: "sustain.uitest.\(UUID().uuidString)") ?? .standard : .standard
        _app = State(initialValue: AppModel(container: container, settings: AppSettings(defaults: defaults)))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .modelContainer(app.container)
                .frame(minWidth: 1024, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Capture…") { app.showCapture = true }.keyboardShortcut("k")
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { app.screen = .settings }.keyboardShortcut(",")
            }
            CommandMenu("Go") {
                Button("Today") { app.screen = .today }.keyboardShortcut("1")
                Button("Library") { app.screen = .library }.keyboardShortcut("2")
                Button("Notes") { app.screen = .notes }.keyboardShortcut("3")
                Button("Log") { app.screen = .log }.keyboardShortcut("4")
            }
            CommandMenu("Debug") {
                OpenWindowButton(title: "YouTube Test…", id: YouTubeSpikeView.windowID)
            }
        }

        Window("YouTube Test", id: YouTubeSpikeView.windowID) {
            YouTubeSpikeView()
                .themed()
                .frame(minWidth: 820, minHeight: 720)
        }
        .defaultSize(width: 980, height: 820)
    }
}

/// Applies the Appearance setting and keeps Today current across midnight and sleep.
private struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ContentView()
            .themed()
            .preferredColorScheme(app.settings.mode == .system ? nil : app.settings.mode == .dark ? .dark : .light)
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: RunLoop.main)) { _ in
                app.refreshDay()
            }
            .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).receive(on: RunLoop.main)) { _ in
                app.refreshDay()
            }
            .onChange(of: scenePhase) { if scenePhase == .active { app.refreshDay() } }
    }
}

/// Menu commands can't read the environment directly; a tiny view can.
private struct OpenWindowButton: View {
    let title: String
    let id: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(title) { openWindow(id: id) }
    }
}
