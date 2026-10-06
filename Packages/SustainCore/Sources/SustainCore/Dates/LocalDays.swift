import Foundation

/// Calendar-day math in the user's calendar. Practice works in local days, not 24-hour blocks.
public struct LocalDays: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// UTC days. Used to match ts-fsrs in the parity fixtures.
    public static let utc: LocalDays = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return LocalDays(calendar: cal)
    }()

    public func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Adds calendar days, so a DST change doesn't move the hour.
    public func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date.addingTimeInterval(Double(days) * 86_400)
    }

    public func endOfDay(_ date: Date) -> Date {
        addDays(1, to: startOfDay(date)).addingTimeInterval(-0.001)
    }

    /// Whole calendar days from `a` to `b` (positive when `b` is later).
    public func daysBetween(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: startOfDay(a), to: startOfDay(b)).day ?? 0
    }

    public func isSameDay(_ a: Date, _ b: Date) -> Bool {
        daysBetween(a, b) == 0
    }

    /// Local calendar day as YYYY-MM-DD.
    public func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(pad2(c.month ?? 0))-\(pad2(c.day ?? 0))"
    }
}

/// 83 -> "01:23"
public func formatClock(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return "\(pad2(s / 60)):\(pad2(s % 60))"
}

func pad2(_ n: Int) -> String {
    n < 10 ? "0\(n)" : "\(n)"
}
