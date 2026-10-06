import Foundation

public struct SchedulerSettings: Codable, Sendable, Equatable {
    /// Desired retention, 0.80–0.97.
    public var retention: Double
    /// Longest gap in days, 30–120. Nothing goes longer without a check-in.
    public var maxInterval: Int

    public init(retention: Double = 0.9, maxInterval: Int = 60) {
        self.retention = retention
        self.maxInterval = maxInterval
    }

    public static let retentionRange: ClosedRange<Double> = 0.80...0.97
    public static let maxIntervalRange: ClosedRange<Int> = 30...120
}

public enum Stage: String, Sendable {
    case new = "New", learning = "Learning", review = "Review", mastered = "Mastered"
}

/// Sustain's scheduler: FSRS in days, plus the longest-gap cap the engine can overshoot.
public struct Scheduler: Sendable {
    public let settings: SchedulerSettings
    public let days: LocalDays
    let engine: FSRS

    public init(settings: SchedulerSettings = SchedulerSettings(), days: LocalDays = LocalDays()) {
        self.settings = settings
        self.days = days
        engine = FSRS(retention: settings.retention, maximumInterval: settings.maxInterval)
    }

    /// The card after a rating. To re-rate on the same day, pass the card from before the first rating.
    public func rate(_ card: FSRSCard, _ rating: Rating, at now: Date) -> FSRSCard {
        capInterval(engine.next(card, at: now, rating: rating, days: days), now: now)
    }

    /// Days until each rating would bring the item back (at least 1).
    public func preview(_ card: FSRSCard, at now: Date) -> [Rating: Int] {
        var out: [Rating: Int] = [:]
        for r in Rating.allCases {
            out[r] = max(1, days.daysBetween(now, rate(card, r, at: now).due))
        }
        return out
    }

    /// The engine's interval ordering (again < hard < good < easy) can push past the cap; pull it back, same time of day.
    func capInterval(_ card: FSRSCard, now: Date) -> FSRSCard {
        guard days.daysBetween(now, card.due) > settings.maxInterval else { return card }
        var c = card
        let timeOfDay = card.due.timeIntervalSince(days.startOfDay(card.due))
        c.scheduledDays = settings.maxInterval
        c.due = days.addDays(settings.maxInterval, to: days.startOfDay(now)).addingTimeInterval(timeOfDay)
        return c
    }

    /// Plain-language stage for the Library and the practice card.
    public func stage(of card: FSRSCard) -> Stage {
        if card.state == .new { return .new }
        if card.scheduledDays >= settings.maxInterval { return .mastered }
        if card.state == .learning || card.state == .relearning || card.scheduledDays < 7 { return .learning }
        return .review
    }

    /// Compact interval for the rating buttons: 1d, 9d, 3w, 2mo.
    public static func intervalLabel(_ days: Int) -> String {
        if days < 14 { return "\(days)d" }
        if days < 56 { return "\(Int(jsRound(Double(days) / 7)))w" }
        return "\(Int(jsRound(Double(days) / 30)))mo"
    }

    /// "today", "tomorrow", "in 9d" for lists.
    public static func nextLabel(_ days: Int) -> String {
        if days <= 0 { return "today" }
        if days == 1 { return "tomorrow" }
        return "in \(intervalLabel(days))"
    }
}
