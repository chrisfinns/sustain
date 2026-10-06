import Foundation
@testable import SustainCore

/// UTC calendar so tests don't depend on the machine's time zone.
let utcDays = LocalDays.utc

func date(_ iso: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: iso)!
}

func date(ms: Int64) -> Date {
    Date(timeIntervalSince1970: Double(ms) / 1000)
}

func ms(_ d: Date) -> Int64 {
    Int64((d.timeIntervalSince1970 * 1000).rounded())
}

func fixture(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try Data(contentsOf: url)
}

/// A card in review, due `dueIn` days from `now` (negative = overdue).
func reviewCard(dueIn: Int, now: Date, days: LocalDays = utcDays, stability: Double = 5) -> FSRSCard {
    FSRSCard(due: days.addDays(dueIn, to: now), stability: stability, difficulty: 5, elapsedDays: 3, scheduledDays: 5,
             reps: 3, lapses: 0, state: .review, lastReview: days.addDays(dueIn - 5, to: now))
}
