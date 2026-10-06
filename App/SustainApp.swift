import SwiftUI

@main
struct SustainApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .themed()
                .frame(minWidth: 1024, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
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

/// Menu commands can't read the environment directly; a tiny view can.
private struct OpenWindowButton: View {
    let title: String
    let id: String
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(title) { openWindow(id: id) }
    }
}
