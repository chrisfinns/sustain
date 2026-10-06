import SustainCore
import SwiftUI
import Testing
@testable import Sustain

@MainActor
struct AppThemeTests {
    @Test func everyTokenResolvesInBothModes() {
        for theme in [Theme.dark, Theme.light] {
            for token in Token.allCases {
                _ = theme[token]
            }
        }
        #expect(Theme.dark.tokens.mode == .dark)
        #expect(Theme.light.tokens.mode == .light)
    }

    @Test func playerErrorsHavePlainDescriptions() {
        #expect(YouTubePlayerModel.describe(error: 153).contains("referrer"))
        #expect(YouTubePlayerModel.describe(error: 150) == "The owner doesn't allow embedding")
    }

    @Test func playerMessagesUpdateTheModel() {
        let model = YouTubePlayerModel()
        model.load(videoId: "dQw4w9WgXcQ")
        model.handle(["type": "ready", "rates": [0.5, 0.75, 1.0] as [NSNumber], "duration": 212.0 as NSNumber, "rate": 1.0 as NSNumber])
        #expect(model.isReady)
        #expect(model.availableRates == [0.5, 0.75, 1.0])
        model.handle(["type": "state", "state": 1 as NSNumber])
        #expect(model.isPlaying)
        model.handle(["type": "loopWrap", "overshoot": 0.04 as NSNumber])
        #expect(model.loopOvershoots == [0.04])
        model.handle(["type": "error", "code": 153 as NSNumber])
        #expect(model.errorCode == 153)
    }
}
