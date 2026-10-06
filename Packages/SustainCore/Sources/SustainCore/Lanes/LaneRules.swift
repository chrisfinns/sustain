import Foundation

public enum LaneRules {
    /// The card and warm-up timestamp after a lane change.
    /// Leaving warm-up after practicing it there brings it back tomorrow, so daily reps can't push it out for weeks.
    public static func changeLane(from old: Lane, to new: Lane, card: FSRSCard, warmupSince: Date?,
                                  now: Date, days: LocalDays) -> (card: FSRSCard, warmupSince: Date?) {
        guard old != new else { return (card, warmupSince) }
        if new == .warmup { return (card, now) }
        guard old == .warmup else { return (card, warmupSince) }
        guard let last = card.lastReview, warmupSince.map({ last >= $0 }) ?? true else { return (card, nil) }
        var c = card
        c.due = days.addDays(1, to: days.startOfDay(now))
        c.scheduledDays = max(1, days.daysBetween(last, c.due))
        return (c, nil)
    }
}
