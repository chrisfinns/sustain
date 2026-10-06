import Foundation

public enum PracticeStats {
    /// Consecutive local days with at least one review, ending today, or yesterday if today has none yet.
    public static func streak(reviewDays: Set<String>, today: Date, days: LocalDays) -> Int {
        var day = reviewDays.contains(days.dayKey(today)) ? today : days.addDays(-1, to: today)
        var count = 0
        while reviewDays.contains(days.dayKey(day)) {
            count += 1
            day = days.addDays(-1, to: day)
        }
        return count
    }

    /// Heat level per day, oldest first, ending today: 0 none, 1 for 1–3 reviews, 2 for 4–7, 3 for 8 or more.
    public static func heatmap(reviewsPerDay: [String: Int], today: Date, days: LocalDays, count: Int = 84) -> [Int] {
        (0..<count).map { i in
            let key = days.dayKey(days.addDays(i - (count - 1), to: today))
            return level(reviewsPerDay[key] ?? 0)
        }
    }

    public static func level(_ reviews: Int) -> Int {
        switch reviews {
        case ..<1: 0
        case 1...3: 1
        case 4...7: 2
        default: 3
        }
    }
}
