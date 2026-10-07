import AppKit
import SwiftUI
import SustainCore

/// Video tab: the YouTube player, the A–B loop bar and speed. Loop points and speed are saved per item.
struct VideoPanel: View {
    static let speeds: [Double] = [0.5, 0.6, 0.75, 0.85, 1.0]

    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    let item: Item
    let player: YouTubePlayerModel
    @State private var dragging: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(theme[.vid])
                YouTubePlayerView(model: player).clipShape(RoundedRectangle(cornerRadius: 12))
                if let problem {
                    VStack(spacing: 10) {
                        Text(problem).foregroundStyle(theme[.vidText]).multilineTextAlignment(.center)
                        if let url = item.youtubeURL.flatMap(URL.init(string:)) {
                            Button("Open on YouTube") { NSWorkspace.shared.open(url) }
                                .buttonStyle(OutlineButtonStyle(height: 32, radius: 8))
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme[.vid])
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.vidLine]))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text("A \(YouTubeLink.formatTime(player.loopA))").font(Typo.mono(12)).foregroundStyle(theme[.muted])
                    loopBar.frame(height: 18)
                    Text("B \(YouTubeLink.formatTime(player.loopB))").font(Typo.mono(12)).foregroundStyle(theme[.muted])
                    Button {
                        setLoop(on: !player.loopOn)
                    } label: {
                        Label("Loop A–B", systemImage: "repeat")
                            .font(Typo.meta)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 34)
                            .foregroundStyle(player.loopOn ? theme[.accent] : theme[.muted])
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(player.loopOn ? theme[.accent] : theme[.line4]))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(player.loopOn ? .isSelected : [])
                }
                HStack(spacing: 6) {
                    Text("Speed").font(Typo.small).foregroundStyle(theme[.muted]).padding(.trailing, 6)
                    ForEach(Self.speeds, id: \.self) { v in
                        let on = abs(player.rate - v) < 0.001
                        Button {
                            item.speed = v
                            app.save()
                            player.setRate(v)
                        } label: {
                            Text("\(Int((v * 100).rounded()))%")
                                .font(Typo.mono(12))
                                .padding(.horizontal, 10)
                                .frame(minHeight: 32)
                                .foregroundStyle(on ? theme[.onAccent] : theme[.text])
                                .background(on ? theme[.accent] : theme[.raised2], in: RoundedRectangle(cornerRadius: 7))
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                    Spacer()
                    Button("Set A here") { player.mark("a") }.buttonStyle(OutlineButtonStyle(height: 32, radius: 7)).font(Typo.small)
                    Button("Set B here") { player.mark("b") }.buttonStyle(OutlineButtonStyle(height: 32, radius: 7)).font(Typo.small)
                }
                .disabled(!player.isReady)
            }
            .card(padding: 14)
        }
        .onChange(of: player.loopA) { persistLoop() }
        .onChange(of: player.loopB) { persistLoop() }
    }

    private var problem: String? {
        if player.isOffline { return "The video needs an internet connection." }
        if let code = player.errorCode { return YouTubePlayerModel.describe(error: code) + "." }
        return nil
    }

    /// The loop bar: A–B fill, the playhead, and draggable ends.
    private var loopBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let d = max(player.duration, 1)
            let x = { (t: Double?) -> CGFloat in CGFloat((t ?? 0) / d) * w }
            ZStack(alignment: .leading) {
                Capsule().fill(theme[.line]).frame(height: 10)
                if let a = player.loopA, let b = player.loopB, b > a {
                    Capsule().fill(player.loopOn ? theme[.accent] : theme[.line6])
                        .frame(width: max(4, x(b) - x(a)), height: 10)
                        .offset(x: x(a))
                }
                Rectangle().fill(theme[.text]).frame(width: 2, height: 18).offset(x: x(player.currentTime))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let t = Double(max(0, min(w, g.location.x)) / w) * d
                    if dragging == nil {
                        let da = abs((player.loopA ?? 0) - t), db = abs((player.loopB ?? d) - t)
                        dragging = player.loopA == nil || da <= db ? "a" : "b"
                    }
                    if dragging == "a" {
                        player.loopA = min(t, (player.loopB ?? d) - 0.5)
                    } else {
                        player.loopB = max(t, (player.loopA ?? 0) + 0.5)
                    }
                }
                .onEnded { _ in
                    dragging = nil
                    player.setLoop(a: player.loopA, b: player.loopB, on: player.loopOn)
                })
            .accessibilityLabel("Loop from \(YouTubeLink.formatTime(player.loopA)) to \(YouTubeLink.formatTime(player.loopB))")
        }
    }

    private func setLoop(on: Bool) {
        player.setLoop(a: player.loopA, b: player.loopB, on: on)
        item.loopOn = on
        app.save()
    }

    private func persistLoop() {
        guard item.loopA != player.loopA || item.loopB != player.loopB else { return }
        item.loopA = player.loopA
        item.loopB = player.loopB
        app.save()
    }
}

/// Video tab with no video yet: paste a link right here.
struct AddVideoPanel: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    let item: Item
    @State private var link = ""
    @State private var problem: String?

    var body: some View {
        EmptyMediaState(icon: "play.rectangle", title: "No video yet",
                        text: "Paste a YouTube link. It embeds right here with A–B loop and speed control.") {
            HStack(spacing: 8) {
                TextField("youtube.com/watch?v=…", text: $link)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 320)
                    .onSubmit(add)
                Button("Add", action: add).buttonStyle(OutlineButtonStyle(height: 30, radius: 7))
            }
            if let problem { Text(problem).font(Typo.small).foregroundStyle(theme[.again]) }
        }
    }

    private func add() {
        guard let id = YouTubeLink.videoId(link) else {
            problem = "That doesn't look like a YouTube link."
            return
        }
        item.youtubeURL = link.trimmingCharacters(in: .whitespacesAndNewlines)
        item.youtubeId = id
        item.loopA = YouTubeLink.startSeconds(link).map(Double.init)
        app.save()
    }
}

struct EmptyMediaState<Extra: View>: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let text: String
    @ViewBuilder var extra: () -> Extra

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(theme[.muted])
            Text(title).font(.system(size: 15, weight: .semibold))
            Text(text).foregroundStyle(theme[.muted]).multilineTextAlignment(.center).frame(maxWidth: 380)
            extra()
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.line5], style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }
}

/// PDFs and takes until their viewers land: a list that opens each file in its default app.
struct AttachmentList: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    let attachments: [Attachment]
    let emptyTitle: String
    let emptyText: String

    var body: some View {
        if attachments.isEmpty {
            EmptyMediaState(icon: "tray.and.arrow.down", title: emptyTitle, text: emptyText) { EmptyView() }
        } else {
            VStack(spacing: 10) {
                ForEach(attachments) { a in
                    HStack(spacing: 14) {
                        Image(systemName: a.kind == .audio ? "waveform" : a.kind == .pdf ? "doc.richtext" : "doc")
                            .frame(width: 36, height: 36)
                            .background(theme[.line], in: Circle())
                        Text(a.name).fontWeight(.semibold).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        Text(ByteCountFormatter.string(fromByteCount: Int64(a.size), countStyle: .file))
                            .font(Typo.mono(12)).foregroundStyle(theme[.muted])
                        Button("Open") {
                            if let url = app.media?.url(for: a.fileName) { NSWorkspace.shared.open(url) }
                        }
                        .buttonStyle(OutlineButtonStyle(height: 32, radius: 7))
                        .font(Typo.small)
                    }
                    .card(padding: 12, radius: 10)
                }
            }
        }
    }
}

/// Images tab: a grid of screenshots, plus a tile that pastes one from the clipboard.
struct ImageGrid: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    let attachments: [Attachment]
    let onPaste: () -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            ForEach(attachments) { a in
                VStack(alignment: .leading, spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(theme[.raised])
                        if let url = app.media?.url(for: a.fileName), let image = NSImage(contentsOf: url) {
                            Image(nsImage: image).resizable().scaledToFill()
                        } else {
                            Image(systemName: "photo").font(.system(size: 28)).foregroundStyle(theme[.faint])
                        }
                    }
                    .aspectRatio(4 / 3, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line2]))
                    .onTapGesture {
                        if let url = app.media?.url(for: a.fileName) { NSWorkspace.shared.open(url) }
                    }
                    Text(a.name).font(Typo.small).foregroundStyle(theme[.muted]).lineLimit(1)
                }
            }
            Button(action: onPaste) {
                VStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .medium))
                    Text("Paste a screenshot").font(Typo.meta)
                    KeyCap("⌘V")
                }
                .foregroundStyle(theme[.muted])
                .frame(maxWidth: .infinity)
                .aspectRatio(4 / 3, contentMode: .fit)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line5], style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Paste a screenshot")
        }
    }
}
