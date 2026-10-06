import Foundation

/// Where an item sits in Today. Warm-up is a per-item setting, not an area.
public enum Lane: String, Codable, Sendable, CaseIterable {
    case normal, focus, warmup

    /// Label in the Schedule control.
    public var label: String {
        switch self {
        case .normal: "Regular"
        case .focus: "Focus"
        case .warmup: "Warm-up"
        }
    }

    public var hint: String {
        switch self {
        case .normal: "Comes back right before you'd forget it, further apart each time you nail it"
        case .focus: "Comes first whenever it's due. Keep it to 3–5"
        case .warmup: "Every day, before everything else"
        }
    }
}

public enum Rating: Int, Codable, Sendable, CaseIterable, Comparable {
    case again = 1, hard = 2, good = 3, easy = 4

    public static let simple: [Rating] = [.again, .good]

    public var label: String {
        switch self {
        case .again: "Again"
        case .hard: "Hard"
        case .good: "Good"
        case .easy: "Easy"
        }
    }

    /// Short hint under the button.
    public var hint: String {
        switch self {
        case .again: "Fell apart"
        case .hard: "Slow or sloppy"
        case .good: "Clean at target"
        case .easy: "Effortless"
        }
    }

    /// Tooltip with the musician meaning.
    public var tip: String {
        switch self {
        case .again: "It fell apart. It comes back soon."
        case .hard: "Got through it, but slow or with mistakes."
        case .good: "Played it clean at your target tempo."
        case .easy: "Clean and effortless, at or above tempo."
        }
    }

    public static func < (a: Rating, b: Rating) -> Bool { a.rawValue < b.rawValue }
}

/// The 8 data colors for areas and instruments. Stored as names, resolved to a hex per mode.
public enum ColorName: String, Codable, Sendable, CaseIterable {
    case amber, coral, rose, violet, blue, teal, green, slate

    public var next: ColorName {
        let all = ColorName.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// The first palette color with the fewest uses.
    public static func leastUsed(_ used: [ColorName]) -> ColorName {
        let counts = allCases.map { c in used.filter { $0 == c }.count }
        let low = counts.min() ?? 0
        return allCases[counts.firstIndex(of: low) ?? 0]
    }
}

/// ts-fsrs card states. Sustain's long-term scheduler only ever produces `.new` and `.review`.
public enum CardState: Int, Codable, Sendable {
    case new = 0, learning = 1, review = 2, relearning = 3
}

/// An FSRS card as stored with each item.
public struct FSRSCard: Codable, Sendable, Equatable {
    public var due: Date
    public var stability: Double
    public var difficulty: Double
    public var elapsedDays: Int
    public var scheduledDays: Int
    public var reps: Int
    public var lapses: Int
    public var state: CardState
    public var lastReview: Date?

    public init(due: Date, stability: Double = 0, difficulty: Double = 0, elapsedDays: Int = 0, scheduledDays: Int = 0,
                reps: Int = 0, lapses: Int = 0, state: CardState = .new, lastReview: Date? = nil) {
        self.due = due
        self.stability = stability
        self.difficulty = difficulty
        self.elapsedDays = elapsedDays
        self.scheduledDays = scheduledDays
        self.reps = reps
        self.lapses = lapses
        self.state = state
        self.lastReview = lastReview
    }

    public static func new(at now: Date) -> FSRSCard { FSRSCard(due: now) }

    public var isNew: Bool { state == .new }
}
