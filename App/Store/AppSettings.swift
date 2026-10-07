import Foundation
import Observation
import SustainCore

/// User settings, kept in UserDefaults and included in backups.
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var retention: Double { didSet { defaults.set(retention, forKey: Keys.retention) } }
    var maxInterval: Int { didSet { defaults.set(maxInterval, forKey: Keys.maxInterval) } }
    var newPerDay: Int { didSet { defaults.set(newPerDay, forKey: Keys.newPerDay) } }
    /// Simple mode: only Again and Good.
    var simple: Bool { didSet { defaults.set(simple, forKey: Keys.simple) } }
    var mode: ModeSetting { didSet { defaults.set(mode.rawValue, forKey: Keys.mode) } }
    var lastBackupAt: Date? { didSet { defaults.set(lastBackupAt, forKey: Keys.lastBackupAt) } }
    /// The Scales tab's exercise, as last set. A preference, so it isn't in backups.
    var scales: ScaleExercise { didSet { defaults.set(try? JSONEncoder().encode(scales), forKey: Keys.scales) } }

    private enum Keys {
        static let retention = "retention"
        static let maxInterval = "maxInterval"
        static let newPerDay = "newPerDay"
        static let simple = "simple"
        static let mode = "mode"
        static let lastBackupAt = "lastBackupAt"
        static let scales = "scales"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let r = defaults.double(forKey: Keys.retention)
        retention = SchedulerSettings.retentionRange.contains(r) ? r : 0.9
        let m = defaults.integer(forKey: Keys.maxInterval)
        maxInterval = SchedulerSettings.maxIntervalRange.contains(m) ? m : 60
        let n = defaults.integer(forKey: Keys.newPerDay)
        newPerDay = (1...10).contains(n) ? n : 3
        simple = defaults.bool(forKey: Keys.simple)
        mode = ModeSetting(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .system
        lastBackupAt = defaults.object(forKey: Keys.lastBackupAt) as? Date
        scales = defaults.data(forKey: Keys.scales).flatMap { try? JSONDecoder().decode(ScaleExercise.self, from: $0) } ?? ScaleExercise()
    }

    var scheduler: SchedulerSettings {
        SchedulerSettings(retention: retention, maxInterval: maxInterval)
    }

    /// The rating buttons to show, in key order (1, 2, …).
    var ratings: [Rating] { simple ? Rating.simple : Rating.allCases }
}
