import Foundation

/// What Today needs to know about an item. Areas are deliberately absent: they never change Today.
public struct QueueItem: Sendable, Equatable, Identifiable {
    public var id: String
    public var instrumentId: String
    public var lane: Lane
    public var paused: Bool
    public var reference: Bool
    public var card: FSRSCard
    public var createdAt: Date
    /// Rated at least once today.
    public var ratedToday: Bool
    /// Its first-ever rating happened today, so it used one of today's New slots.
    public var startedToday: Bool

    public init(id: String, instrumentId: String, lane: Lane = .normal, paused: Bool = false, reference: Bool = false,
                card: FSRSCard, createdAt: Date, ratedToday: Bool = false, startedToday: Bool = false) {
        self.id = id
        self.instrumentId = instrumentId
        self.lane = lane
        self.paused = paused
        self.reference = reference
        self.card = card
        self.createdAt = createdAt
        self.ratedToday = ratedToday
        self.startedToday = startedToday
    }

    var isActive: Bool { !paused && !reference }
}

/// Time budget: about 3 minutes per item.
public enum TimeBudget: Int, Sendable, CaseIterable {
    case fifteen = 15, twenty = 20, thirty = 30, all = 0

    public var label: String { self == .all ? "All" : "\(rawValue)m" }

    /// Items that fit, or nil for no limit. 15m → 5, 20m → 7, 30m → 10.
    public var itemCap: Int? { self == .all ? nil : Int(jsRound(Double(rawValue) / 3)) }
}

public struct TodayQueue: Sendable, Equatable {
    public var warmup: [QueueItem] = []
    public var focus: [QueueItem] = []
    public var due: [QueueItem] = []
    public var fresh: [QueueItem] = []
    /// Rated today, in the order they were rated.
    public var done: [QueueItem] = []
    /// Everything to practice, in session order, after the budget.
    public var ids: [String] = []
    /// New items over today's cap.
    public var waiting = 0
    /// Items over the time budget. They stay due.
    public var cut = 0
    /// New items already started today (they used a slot).
    public var newStartedToday = 0
    public var newPerDay = 3
    /// Days overdue per item id (0 = due today).
    public var overdue: [String: Int] = [:]

    public var isEmpty: Bool { ids.isEmpty }

    /// Builds Today. Warm-ups, then Focus, then Due (most overdue first), then New (capped), then the budget.
    /// `instrumentId` nil means all instruments. The New cap is global and applies before the instrument filter.
    public static func build(items: [QueueItem], now: Date, days: LocalDays, newPerDay: Int,
                             instrumentId: String? = nil, budget: TimeBudget = .all) -> TodayQueue {
        var q = TodayQueue()
        q.newPerDay = newPerDay
        let inFilter: (QueueItem) -> Bool = { instrumentId == nil || $0.instrumentId == instrumentId }
        let overdueDays: (QueueItem) -> Int = { days.daysBetween($0.card.due, now) }
        let isDue: (QueueItem) -> Bool = { !$0.card.isNew && overdueDays($0) >= 0 }
        let byOverdue: (QueueItem, QueueItem) -> Bool = { a, b in
            let (oa, ob) = (overdueDays(a), overdueDays(b))
            if oa != ob { return oa > ob }
            if a.card.due != b.card.due { return a.card.due < b.card.due }
            return a.createdAt < b.createdAt
        }
        let open = items.filter { $0.isActive && !$0.ratedToday }

        q.warmup = open.filter { $0.lane == .warmup && inFilter($0) }.sorted { $0.createdAt < $1.createdAt }
        q.focus = open.filter { $0.lane == .focus && isDue($0) && inFilter($0) }.sorted(by: byOverdue)
        q.due = open.filter { $0.lane == .normal && isDue($0) && inFilter($0) }.sorted(by: byOverdue)

        // Warm-ups never take a New slot.
        let newAll = open.filter { $0.card.isNew && $0.lane != .warmup }.sorted { $0.createdAt < $1.createdAt }
        q.newStartedToday = items.filter { $0.startedToday && $0.lane != .warmup }.count
        let slots = max(0, newPerDay - q.newStartedToday)
        let newGlobal = Array(newAll.prefix(slots))
        q.waiting = newAll.count - newGlobal.count
        q.fresh = newGlobal.filter(inFilter)

        let ordered = q.warmup + q.focus + q.due + q.fresh
        let kept = budget.itemCap.map { Array(ordered.prefix($0)) } ?? ordered
        q.cut = ordered.count - kept.count
        q.ids = kept.map(\.id)
        let keptIds = Set(q.ids)
        q.warmup = q.warmup.filter { keptIds.contains($0.id) }
        q.focus = q.focus.filter { keptIds.contains($0.id) }
        q.due = q.due.filter { keptIds.contains($0.id) }
        q.fresh = q.fresh.filter { keptIds.contains($0.id) }

        q.done = items.filter { $0.ratedToday && inFilter($0) }
            .sorted { ($0.card.lastReview ?? .distantPast) < ($1.card.lastReview ?? .distantPast) }
        for item in kept where !item.card.isNew {
            q.overdue[item.id] = max(0, overdueDays(item))
        }
        return q
    }

    /// Today's count per instrument for the sidebar (all instruments, no budget).
    public static func countsByInstrument(items: [QueueItem], now: Date, days: LocalDays, newPerDay: Int) -> [String: Int] {
        let all = build(items: items, now: now, days: days, newPerDay: newPerDay)
        let byId = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var out: [String: Int] = [:]
        for id in all.ids {
            if let inst = byId[id]?.instrumentId { out[inst, default: 0] += 1 }
        }
        return out
    }
}
