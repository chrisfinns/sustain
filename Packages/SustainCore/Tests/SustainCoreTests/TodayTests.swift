import Foundation
import Testing
@testable import SustainCore

@Suite struct TodayQueueTests {
    let now = date("2026-10-06T15:00:00Z")

    func item(_ id: String, inst: String = "guitar", lane: Lane = .normal, dueIn: Int? = nil, created: Int = 0,
              paused: Bool = false, reference: Bool = false, ratedToday: Bool = false, startedToday: Bool = false) -> QueueItem {
        let card = dueIn.map { reviewCard(dueIn: $0, now: now) } ?? .new(at: now)
        return QueueItem(id: id, instrumentId: inst, lane: lane, paused: paused, reference: reference, card: card,
                         createdAt: now.addingTimeInterval(Double(created)), ratedToday: ratedToday, startedToday: startedToday)
    }

    func build(_ items: [QueueItem], newPerDay: Int = 3, inst: String? = nil, budget: TimeBudget = .all, at: Date? = nil) -> TodayQueue {
        TodayQueue.build(items: items, now: at ?? now, days: utcDays, newPerDay: newPerDay, instrumentId: inst, budget: budget)
    }

    @Test func sectionsComeInOrderAndDueIsMostOverdueFirst() {
        let q = build([
            item("due-0", dueIn: 0), item("due-5late", dueIn: -5), item("later", dueIn: 4),
            item("focus-2late", lane: .focus, dueIn: -2), item("focus-later", lane: .focus, dueIn: 3),
            item("warm-b", lane: .warmup, dueIn: 9, created: 2), item("warm-a", lane: .warmup, dueIn: 30, created: 1),
            item("new-1", created: 5),
        ])
        #expect(q.warmup.map(\.id) == ["warm-a", "warm-b"])
        #expect(q.focus.map(\.id) == ["focus-2late"])
        #expect(q.due.map(\.id) == ["due-5late", "due-0"])
        #expect(q.fresh.map(\.id) == ["new-1"])
        #expect(q.ids == ["warm-a", "warm-b", "focus-2late", "due-5late", "due-0", "new-1"])
        #expect(q.overdue["due-5late"] == 5)
        #expect(q.overdue["due-0"] == 0)
    }

    @Test func newItemsAreCappedPerDay() {
        let items = (1...5).map { item("n\($0)", created: $0) }
        let q = build(items)
        #expect(q.fresh.map(\.id) == ["n1", "n2", "n3"])
        #expect(q.waiting == 2)
    }

    @Test func newItemsStartedTodayUseUpSlots() {
        var items = (1...5).map { item("n\($0)", created: $0) }
        items.append(item("s1", dueIn: 2, ratedToday: true, startedToday: true))
        items.append(item("s2", dueIn: 2, ratedToday: true, startedToday: true))
        let q = build(items)
        #expect(q.newStartedToday == 2)
        #expect(q.fresh.map(\.id) == ["n1"])
        #expect(q.waiting == 4)
    }

    @Test func pausedAndReferenceItemsNeverShow() {
        let q = build([
            item("p", dueIn: -1, paused: true), item("r", dueIn: -1, reference: true),
            item("pw", lane: .warmup, paused: true), item("rn", reference: true), item("ok", dueIn: 0),
        ])
        #expect(q.ids == ["ok"])
    }

    @Test func timeBudgetTrimsAndReportsTheRest() {
        let items = (0..<9).map { item("d\($0)", dueIn: -$0) }
        let q = build(items, budget: .fifteen)
        #expect(q.ids.count == 5)
        #expect(q.cut == 4)
        #expect(q.ids.first == "d8")
        #expect(TimeBudget.twenty.itemCap == 7)
        #expect(TimeBudget.thirty.itemCap == 10)
        #expect(TimeBudget.all.itemCap == nil)
    }

    @Test func warmUpsComeFirstAndNeverTakeANewSlotOrShowTwice() {
        let items = [
            item("n1", created: 1), item("n2", created: 2), item("n3", created: 3),
            item("warm-new", lane: .warmup, created: 0),
            item("warm-due", lane: .warmup, dueIn: -3),
        ]
        let q = build(items)
        #expect(q.ids.prefix(2).sorted() == ["warm-due", "warm-new"])
        #expect(q.fresh.map(\.id) == ["n1", "n2", "n3"])
        #expect(Set(q.ids).count == q.ids.count)
        #expect(!q.due.contains { $0.lane == .warmup })
    }

    @Test func ratedTodayMovesToDone() {
        let q = build([item("w", lane: .warmup, dueIn: 1, ratedToday: true), item("d", dueIn: -1, ratedToday: true), item("x", dueIn: 0)])
        #expect(q.ids == ["x"])
        #expect(Set(q.done.map(\.id)) == ["w", "d"])
    }

    @Test func newCapIsGlobalAndTheInstrumentFilterAppliesAfterIt() {
        let items = [item("g1", created: 1), item("b1", inst: "bass", created: 2), item("g2", created: 3), item("b2", inst: "bass", created: 4)]
        let q = build(items, inst: "bass")
        #expect(q.fresh.map(\.id) == ["b1"])
        let counts = TodayQueue.countsByInstrument(items: items, now: now, days: utcDays, newPerDay: 3)
        #expect(counts == ["guitar": 2, "bass": 1])
    }

    @Test func dayRolloverBringsTomorrowsItemsIn() {
        let items = [item("tomorrow", dueIn: 1)]
        #expect(build(items).isEmpty)
        let midnight = date("2026-10-07T00:00:01Z")
        #expect(build(items, at: midnight).ids == ["tomorrow"])
    }

    @Test func emptyQueue() {
        #expect(build([]).isEmpty)
    }
}

@Suite struct LaneRuleTests {
    let now = date("2026-10-06T15:00:00Z")

    @Test func aWarmUpPracticedThereComesBackTomorrowWhenMovedToRegular() {
        var card = reviewCard(dueIn: 40, now: now)
        card.lastReview = now.addingTimeInterval(-3600)
        let since = now.addingTimeInterval(-86_400 * 20)
        let out = LaneRules.changeLane(from: .warmup, to: .normal, card: card, warmupSince: since, now: now, days: utcDays)
        #expect(utcDays.daysBetween(now, out.card.due) == 1)
        #expect(out.warmupSince == nil)
    }

    @Test func aWarmUpNeverPracticedThereKeepsItsSchedule() {
        var card = reviewCard(dueIn: 12, now: now)
        card.lastReview = now.addingTimeInterval(-86_400 * 3)
        let since = now.addingTimeInterval(-60)
        let out = LaneRules.changeLane(from: .warmup, to: .focus, card: card, warmupSince: since, now: now, days: utcDays)
        #expect(out.card == card)
        let fresh = LaneRules.changeLane(from: .warmup, to: .normal, card: .new(at: now), warmupSince: since, now: now, days: utcDays)
        #expect(fresh.card.isNew)
    }

    @Test func enteringWarmUpRemembersWhen() {
        let card = reviewCard(dueIn: 3, now: now)
        let out = LaneRules.changeLane(from: .normal, to: .warmup, card: card, warmupSince: nil, now: now, days: utcDays)
        #expect(out.warmupSince == now)
        #expect(out.card == card)
    }
}

@Suite struct PracticeStatsTests {
    @Test func streakCountsBackFromTodayOrYesterday() {
        let today = date("2026-10-06T15:00:00Z")
        let days: Set<String> = ["2026-10-03", "2026-10-04", "2026-10-05"]
        #expect(PracticeStats.streak(reviewDays: days, today: today, days: utcDays) == 3)
        #expect(PracticeStats.streak(reviewDays: days.union(["2026-10-06"]), today: today, days: utcDays) == 4)
        #expect(PracticeStats.streak(reviewDays: ["2026-10-01"], today: today, days: utcDays) == 0)
    }

    @Test func streakAcrossDSTAndTheYearBoundary() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let la = LocalDays(calendar: cal)
        // DST starts Mar 8, 2026 in the US.
        let mar9 = date("2026-03-09T18:00:00Z")
        #expect(PracticeStats.streak(reviewDays: ["2026-03-07", "2026-03-08", "2026-03-09"], today: mar9, days: la) == 3)
        let jan1 = date("2027-01-01T20:00:00Z")
        #expect(PracticeStats.streak(reviewDays: ["2026-12-30", "2026-12-31", "2027-01-01"], today: jan1, days: la) == 3)
        #expect(la.dayKey(date("2026-03-08T09:30:00Z")) == "2026-03-08")
    }

    @Test func heatmapEndsTodayWithFourLevels() {
        let today = date("2026-10-06T15:00:00Z")
        let map = PracticeStats.heatmap(reviewsPerDay: ["2026-10-06": 9, "2026-10-05": 4, "2026-10-04": 1, "2026-07-15": 3],
                                        today: today, days: utcDays)
        #expect(map.count == 84)
        #expect(Array(map.suffix(3)) == [1, 2, 3])
        #expect(map.first == 1) // Jul 15 is the 84th day back
        #expect(PracticeStats.level(0) == 0)
    }
}
