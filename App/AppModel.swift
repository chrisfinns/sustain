import Foundation
import Observation
import SwiftData
import SustainCore

/// App-wide UI state: navigation, filters, the running session and the toast.
@Observable
final class AppModel {
    var screen: Screen = .today
    /// Sidebar instrument filter; nil = all.
    var instrumentFilter: String?
    var budget: TimeBudget = .all
    /// Library filters live here so Settings › Areas can link into them.
    var libraryStatus: LibraryStatus = .active
    /// "all", "none", or an area id.
    var libraryArea = "all"
    var showCapture = false
    /// The instrument Capture last used.
    var lastInstrumentId: String?
    var session: SessionState?
    var toast: Toast?
    /// Bumped on day change and wake, so Today rebuilds.
    var now = Date.now

    let settings: AppSettings
    @ObservationIgnored let container: ModelContainer
    @ObservationIgnored let media: MediaStore?
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    var ctx: ModelContext { container.mainContext }
    var days: LocalDays { LocalDays() }

    init(container: ModelContainer, settings: AppSettings = AppSettings(), media: MediaStore? = try? .appDefault()) {
        self.container = container
        self.settings = settings
        self.media = media
    }

    // MARK: - Toast

    struct Toast: Equatable {
        let id = UUID()
        let text: String
        /// Area changes offer Undo for 10 s.
        var undo: AreaUndo?
    }

    func flash(_ text: String, undo: AreaUndo? = nil) {
        toast = Toast(text: text, undo: undo)
        resumeToast()
    }

    func holdToast() { toastTask?.cancel() }

    func resumeToast() {
        toastTask?.cancel()
        guard let t = toast else { return }
        let ms = t.undo == nil ? 2800 : 10000
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(ms))
            guard !Task.isCancelled, self?.toast?.id == t.id else { return }
            self?.toast = nil
        }
    }

    // MARK: - Data

    func items() -> [Item] {
        (try? ctx.fetch(FetchDescriptor<Item>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func instruments() -> [Instrument] {
        (try? ctx.fetch(FetchDescriptor<Instrument>(sortBy: [SortDescriptor(\.order)]))) ?? []
    }

    func item(id: String) -> Item? {
        var d = FetchDescriptor<Item>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? ctx.fetch(d).first
    }

    var practice: PracticeStore { PracticeStore(ctx: ctx, days: days) }

    func queue(_ items: [Item], budget: TimeBudget? = nil, instrument: String?? = nil) -> TodayQueue {
        let index = practice.todayIndex(now: now)
        let snaps = items.map { practice.queueItem($0, now: now, today: index[$0.id] ?? []) }
        return TodayQueue.build(items: snaps, now: now, days: days, newPerDay: settings.newPerDay,
                                instrumentId: instrument ?? instrumentFilter, budget: budget ?? self.budget)
    }

    func save() {
        try? ctx.save()
    }

    func refreshDay() {
        now = .now
    }
}

enum LibraryStatus: String, CaseIterable {
    case active, paused, reference, all

    var label: String {
        switch self {
        case .active: "Active"
        case .paused: "Paused"
        case .reference: "Reference"
        case .all: "All"
        }
    }
}

/// A practice session in progress.
struct SessionState: Equatable {
    var queue: [String]
    var currentId: String
    var startedAt: Date
    var sessionId: String
    /// Ratings given in this session, by item id.
    var rated: [String: Rating] = [:]

    var position: Int? { queue.firstIndex(of: currentId) }
}

// MARK: - Areas

extension AppModel {
    var areaStore: AreaStore { AreaStore(ctx: ctx) }

    func undoAreaChange() {
        guard let u = toast?.undo else { return }
        let outcome = areaStore.undo(u)
        save()
        switch outcome {
        case let .restore(area, _): flash("Restored \"\(area.name)\"")
        case let .clash(name): flash("Can't undo: \"\(name)\" now uses that name")
        }
    }
}

// MARK: - Sessions

extension AppModel {
    func sessionRow(id: String) -> PracticeSession? {
        var d = FetchDescriptor<PracticeSession>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? ctx.fetch(d).first
    }

    /// Start session: practice Today's queue from the top.
    func startSession(_ items: [Item]) {
        let q = queue(items)
        guard let first = q.ids.first else { return }
        begin(queue: q.ids, current: first)
    }

    /// Opens one item; if it isn't in the running session, it leads a new queue built from Today.
    func open(_ id: String, items: [Item]) {
        if var s = session, s.queue.contains(id) {
            s.currentId = id
            session = s
        } else {
            let rest = queue(items).ids.filter { $0 != id }
            begin(queue: [id] + rest, current: id)
        }
        screen = .practice
        showCapture = false
    }

    private func begin(queue: [String], current: String) {
        if var s = session {
            s.queue = queue
            s.currentId = current
            session = s
        } else {
            let row = PracticeSession(id: Store.newId("ss"), startedAt: .now)
            ctx.insert(row)
            session = SessionState(queue: queue, currentId: current, startedAt: .now, sessionId: row.id)
        }
        screen = .practice
    }

    func rate(_ rating: Rating) {
        guard var s = session, let item = item(id: s.currentId) else { return }
        practice.rate(item, rating, now: .now, settings: settings.scheduler, session: sessionRow(id: s.sessionId))
        s.rated[item.id] = rating
        save()
        if let next = nextInQueue(after: item.id, in: s) {
            s.currentId = next
            session = s
        } else {
            session = s
            endSession()
        }
    }

    func skip() {
        guard var s = session else { return }
        guard let next = nextInQueue(after: s.currentId, in: s) else {
            flash("Nothing else left in this session")
            return
        }
        s.currentId = next
        session = s
    }

    func move(by offset: Int) {
        guard var s = session, let i = s.position else { return }
        let j = i + offset
        guard s.queue.indices.contains(j) else { return }
        s.currentId = s.queue[j]
        session = s
    }

    /// The next item in the queue not yet rated today, wrapping around.
    func nextInQueue(after id: String, in s: SessionState) -> String? {
        let open: (String) -> Bool = { [self] candidate in
            guard candidate != id, let it = item(id: candidate) else { return false }
            return practice.todaysReviews(it, now: .now).isEmpty
        }
        let idx = s.queue.firstIndex(of: id) ?? -1
        return s.queue.dropFirst(idx + 1).first(where: open) ?? s.queue.first(where: open)
    }

    /// Ends the session. It's saved automatically when anything was rated.
    func endSession() {
        guard let s = session else { return }
        let row = sessionRow(id: s.sessionId)
        if s.rated.isEmpty {
            if let row { ctx.delete(row) }
        } else if let row {
            row.endedAt = .now
            row.durationSec = Int(Date.now.timeIntervalSince(s.startedAt))
            let minutes = max(1, row.durationSec / 60)
            flash("Session saved · \(s.rated.count) \(s.rated.count == 1 ? "item" : "items") · \(minutes) min")
        }
        save()
        session = nil
        screen = .today
    }

    /// Re-rate from Done today: undo today's rating and open the item again.
    func rerate(_ item: Item, items: [Item]) {
        practice.rollbackToday(item, now: .now)
        if var s = session {
            s.rated[item.id] = nil
            session = s
        }
        save()
        open(item.id, items: items)
    }
}

// MARK: - Instruments

extension AppModel {
    /// Adds an instrument by name, or finds the one with the same name. Returns its id.
    @discardableResult
    func addInstrument(_ raw: String) -> String? {
        let name = AreaNames.cleanName(raw, max: 24)
        let key = AreaNames.nameKey(name)
        guard !key.isEmpty else { return nil }
        let all = instruments()
        if let existing = all.first(where: { AreaNames.nameKey($0.name) == key }) {
            flash("\"\(existing.name)\" is already on your list")
            return existing.id
        }
        var id = "in_" + AreaNames.slug(name)
        if all.contains(where: { $0.id == id }) { id += "-" + String(Int(Date.now.timeIntervalSince1970), radix: 36) }
        let color = ColorName.leastUsed(all.map(\.color))
        ctx.insert(Instrument(id: id, name: name, color: color, order: (all.map(\.order).max() ?? 0) + 1, createdAt: .now))
        save()
        flash("Added \(name). Areas work across every instrument.")
        return id
    }
}

// MARK: - Sidebar counts

extension AppModel {
    /// Today's count overall and per instrument, ignoring the budget and the filter.
    func todayCounts(_ items: [Item]) -> (total: Int, byInstrument: [String: Int]) {
        let index = practice.todayIndex(now: now)
        let snaps = items.map { practice.queueItem($0, now: now, today: index[$0.id] ?? []) }
        let by = TodayQueue.countsByInstrument(items: snaps, now: now, days: days, newPerDay: settings.newPerDay)
        return (by.values.reduce(0, +), by)
    }
}
