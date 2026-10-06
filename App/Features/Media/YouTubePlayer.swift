import AppKit
import SwiftUI
import SustainCore
import WebKit

/// State of one embedded YouTube player, driven by Resources/player.html.
@Observable
final class YouTubePlayerModel {
    /// YT.PlayerState: -1 unstarted, 0 ended, 1 playing, 2 paused, 3 buffering, 5 cued.
    enum PlayState: Int {
        case unstarted = -1, ended = 0, playing = 1, paused = 2, buffering = 3, cued = 5
    }

    var videoId: String?
    var start = 0
    var isReady = false
    var isOffline = false
    var state: PlayState = .unstarted
    var errorCode: Int?
    var currentTime: Double = 0
    var duration: Double = 0
    var availableRates: [Double] = []
    var rate: Double = 1
    var loopA: Double?
    var loopB: Double?
    var loopOn = false
    /// How far past B the playhead got before each jump back, in seconds.
    var loopOvershoots: [Double] = []
    var rateChecks: [RateCheck] = []
    var jsErrors: [String] = []
    /// Speed to apply once the player is ready (the item's saved speed).
    var preferredRate: Double = 1

    struct RateCheck: Identifiable {
        let id = UUID()
        let asked: Double
        let got: Double
    }

    @ObservationIgnored weak var webView: WKWebView?

    var isPlaying: Bool { state == .playing }

    func load(videoId: String, start: Int = 0) {
        self.videoId = videoId
        self.start = start
        isReady = false
        isOffline = false
        errorCode = nil
        state = .unstarted
        loopOvershoots = []
        rateChecks = []
    }

    func play() { run("sustain.play()") }
    func pause() { run("sustain.pause()") }
    func togglePlay() { isPlaying ? pause() : play() }
    func seek(_ seconds: Double) { run("sustain.seek(\(seconds))") }
    func setRate(_ r: Double) { run("sustain.setRate(\(r))") }
    func mark(_ which: String) { run("sustain.mark('\(which)')") }

    func setLoop(a: Double?, b: Double?, on: Bool) {
        loopA = a
        loopB = b
        loopOn = on
        run("sustain.setLoop(\(a.map { "\($0)" } ?? "null"), \(b.map { "\($0)" } ?? "null"), \(on))")
    }

    private func run(_ script: String) {
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// A message from player.html.
    func handle(_ body: [String: Any]) {
        func num(_ key: String) -> Double? { (body[key] as? NSNumber)?.doubleValue }
        switch (body["type"] as? String) ?? "" {
        case "ready":
            isReady = true
            availableRates = (body["rates"] as? [NSNumber])?.map(\.doubleValue) ?? []
            duration = num("duration") ?? 0
            rate = num("rate") ?? 1
            if loopA != nil || loopB != nil { setLoop(a: loopA, b: loopB, on: loopOn) }
            if abs(preferredRate - 1) > 0.001 { setRate(preferredRate) }
        case "state":
            state = PlayState(rawValue: Int(num("state") ?? -1)) ?? .unstarted
        case "rate":
            rate = num("rate") ?? rate
        case "rateSet":
            if let asked = num("asked"), let got = num("got") { rateChecks.append(RateCheck(asked: asked, got: got)) }
        case "time":
            currentTime = num("t") ?? currentTime
            if let d = num("duration"), d > 0 { duration = d }
        case "mark":
            guard let t = num("t") else { return }
            if body["which"] as? String == "a" {
                setLoop(a: t, b: loopB.flatMap { $0 > t ? $0 : nil }, on: loopOn)
            } else {
                setLoop(a: loopA.flatMap { $0 < t ? $0 : nil }, b: t, on: loopOn)
            }
        case "loopWrap":
            if let o = num("overshoot") { loopOvershoots.append(o) }
        case "error":
            errorCode = Int(num("code") ?? 0)
        case "offline":
            isOffline = true
        case "jsError":
            if let m = body["message"] as? String { jsErrors.append(m) }
        default:
            break
        }
    }

    /// Plain-language meaning of a YouTube player error.
    static func describe(error code: Int) -> String {
        switch code {
        case 2: "Bad video id"
        case 5: "The player hit an HTML5 error"
        case 100: "Video not found or private"
        case 101, 150: "The owner doesn't allow embedding"
        case 152, 153: "YouTube rejected the embed (player configuration / missing referrer)"
        default: "YouTube error \(code)"
        }
    }
}

/// A WKWebView hosting player.html. The page is loaded with an https base URL so YouTube sees a referrer.
struct YouTubePlayerView: NSViewRepresentable {
    let model: YouTubePlayerModel

    static let baseURL = URL(string: "https://player.sustain.local/")!

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "sustain")
        let web = WKWebView(frame: .zero, configuration: config)
        web.underPageBackgroundColor = .black
        model.webView = web
        context.coordinator.loadIfNeeded(web)
        return web
    }

    func updateNSView(_ web: WKWebView, context: Context) {
        context.coordinator.model = model
        model.webView = web
        context.coordinator.loadIfNeeded(web)
    }

    static func dismantleNSView(_ web: WKWebView, coordinator: Coordinator) {
        web.configuration.userContentController.removeScriptMessageHandler(forName: "sustain")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        var model: YouTubePlayerModel
        private var loaded: String?

        init(model: YouTubePlayerModel) {
            self.model = model
        }

        func loadIfNeeded(_ web: WKWebView) {
            guard let id = model.videoId, YouTubeLink.videoId(id) == id else { return }
            let key = "\(id)@\(model.start)"
            guard key != loaded else { return }
            loaded = key
            guard let url = Bundle.main.url(forResource: "player", withExtension: "html"),
                  let template = try? String(contentsOf: url, encoding: .utf8) else { return }
            let html = template
                .replacingOccurrences(of: "__VIDEO_ID__", with: id)
                .replacingOccurrences(of: "__START__", with: String(max(0, model.start)))
            web.loadHTMLString(html, baseURL: YouTubePlayerView.baseURL)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            model.handle(body)
        }
    }
}
