import AppKit
import SwiftUI
import SustainCore

/// M0 step 1: proves the three things the practice card's Video tab depends on, on a real Mac.
/// 1. A YouTube embed plays inside the sandboxed app.  2. Which speeds YouTube honors.  3. How tight the A–B loop is.
/// Debug › YouTube Test… opens it. "Copy report" puts the results on the clipboard.
struct YouTubeSpikeView: View {
    static let windowID = "youtube-spike"
    static let mockupSpeeds: [Double] = [0.5, 0.6, 0.75, 0.85, 1.0]

    @Environment(\.theme) private var theme
    @State private var link = ""
    @State private var linkProblem: String?
    @State private var player = YouTubePlayerModel()
    @State private var testingSpeeds = false
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("YouTube test").font(Typo.modalTitle)
                    Text("Paste a lesson video, press Load, then work down the checks. When you're done, press Copy report and paste it to Claude.")
                        .font(Typo.meta)
                        .foregroundStyle(theme[.muted])
                }

                HStack(spacing: 8) {
                    TextField("Paste a YouTube link", text: $link)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(load)
                    Button("Load", action: load).keyboardShortcut(.return, modifiers: [.command])
                }
                if let linkProblem {
                    Text(linkProblem).font(Typo.small).foregroundStyle(theme[.again])
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(theme[.vid])
                    if player.videoId != nil {
                        YouTubePlayerView(model: player)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("No video yet").foregroundStyle(theme[.vidText])
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.vidLine]))

                checks
            }
            .padding(24)
        }
        .background(theme[.bg])
    }

    private var checks: some View {
        VStack(alignment: .leading, spacing: 12) {
            row("1 · Embed plays", status: embedStatus.text, ok: embedStatus.ok) {
                Button(player.isPlaying ? "Pause" : "Play") { player.togglePlay() }
                    .disabled(!player.isReady)
            }

            row("2 · Speeds", status: speedStatus, ok: speedsOK) {
                Button(testingSpeeds ? "Testing…" : "Test 50–100 %") { testSpeeds() }
                    .disabled(!player.isReady || testingSpeeds)
            }
            if !player.availableRates.isEmpty {
                Text("YouTube offers: " + player.availableRates.map(percent).joined(separator: ", "))
                    .font(Typo.mono(12)).foregroundStyle(theme[.muted])
            }
            ForEach(player.rateChecks) { check in
                Text("asked \(percent(check.asked)) → got \(percent(check.got))")
                    .font(Typo.mono(12))
                    .foregroundStyle(abs(check.asked - check.got) < 0.001 ? theme[.easy] : theme[.again])
            }

            row("3 · A–B loop", status: loopStatus, ok: loopOK) {
                HStack(spacing: 6) {
                    Button("Set A here") { player.mark("a") }
                    Button("Set B here") { player.mark("b") }
                    Toggle("Loop", isOn: Binding(
                        get: { player.loopOn },
                        set: { player.setLoop(a: player.loopA, b: player.loopB, on: $0) }
                    ))
                    .toggleStyle(.switch)
                }
                .disabled(!player.isReady)
            }
            Text("A \(YouTubeLink.formatTime(player.loopA)) · B \(YouTubeLink.formatTime(player.loopB)) · now \(YouTubeLink.formatTime(player.currentTime)) · speed \(percent(player.rate))")
                .font(Typo.mono(12)).foregroundStyle(theme[.muted])

            HStack {
                Spacer()
                Button(copied ? "Copied" : "Copy report") { copyReport() }
                    .disabled(player.videoId == nil)
            }
        }
        .padding(16)
        .background(theme[.surf], in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.line]))
    }

    private func row<Controls: View>(_ title: String, status: String, ok: Bool?, @ViewBuilder controls: () -> Controls) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: ok == nil ? "circle.dashed" : ok! ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok == nil ? theme[.faint] : ok! ? theme[.easy] : theme[.again])
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typo.rowTitle)
                Text(status).font(Typo.meta).foregroundStyle(theme[.muted])
            }
            Spacer()
            controls()
        }
    }

    // MARK: - Status

    private var embedStatus: (text: String, ok: Bool?) {
        if player.videoId == nil { return ("Load a video first", nil) }
        if player.isOffline { return ("Couldn't reach youtube.com. Check the network.", false) }
        if let code = player.errorCode { return ("Error \(code): \(YouTubePlayerModel.describe(error: code))", false) }
        if player.isPlaying || player.currentTime > 0.5 { return ("Playing", true) }
        if player.isReady { return ("Player ready. Press Play.", nil) }
        return ("Loading…", nil)
    }

    private var speedsOK: Bool? {
        guard !player.rateChecks.isEmpty else { return nil }
        return player.rateChecks.allSatisfy { abs($0.asked - $0.got) < 0.001 }
    }

    private var speedStatus: String {
        guard let ok = speedsOK else { return "Checks 50, 60, 75, 85 and 100 %" }
        return ok ? "All five speeds honored" : "Some speeds were rounded (see below)"
    }

    private var loopOK: Bool? {
        guard player.loopOvershoots.count >= 3 else { return nil }
        return (player.loopOvershoots.max() ?? 0) <= 0.1
    }

    private var loopStatus: String {
        let n = player.loopOvershoots.count
        guard n > 0 else { return "Set A and B a few seconds apart, turn Loop on, let it wrap 3+ times" }
        let worst = Int(((player.loopOvershoots.max() ?? 0) * 1000).rounded())
        let avg = Int((player.loopOvershoots.reduce(0, +) / Double(n) * 1000).rounded())
        return "\(n) wraps · overshoot avg \(avg) ms, worst \(worst) ms (target ≤ 100 ms)"
    }

    // MARK: - Actions

    private func load() {
        guard let id = YouTubeLink.videoId(link) else {
            linkProblem = "That doesn't look like a YouTube link."
            return
        }
        linkProblem = nil
        copied = false
        player.load(videoId: id, start: YouTubeLink.startSeconds(link) ?? 0)
    }

    private func testSpeeds() {
        testingSpeeds = true
        player.rateChecks = []
        Task {
            for r in Self.mockupSpeeds {
                player.setRate(r, check: true)
                try? await Task.sleep(for: .milliseconds(900))
            }
            player.setRate(1)
            testingSpeeds = false
        }
    }

    private func copyReport() {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        var lines = [
            "Sustain YouTube test",
            "macOS: \(os)",
            "video: \(player.videoId ?? "-")",
            "embed: \(embedStatus.text)",
            "rates offered: \(player.availableRates.map(percent).joined(separator: ", "))",
        ]
        lines += player.rateChecks.map { "rate asked \(percent($0.asked)) got \(percent($0.got))" }
        lines.append("loop: \(loopStatus)")
        if !player.loopOvershoots.isEmpty {
            lines.append("overshoots ms: " + player.loopOvershoots.map { String(Int(($0 * 1000).rounded())) }.joined(separator: ", "))
        }
        if !player.jsErrors.isEmpty { lines.append("js errors: " + player.jsErrors.joined(separator: " | ")) }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
        copied = true
    }

    private func percent(_ r: Double) -> String { "\(Int((r * 100).rounded())) %" }
}
