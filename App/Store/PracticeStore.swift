import Foundation
import SwiftData
import SustainCore

/// Ratings, re-rates and the inputs Today needs.
struct PracticeStore {
    let ctx: ModelContext
    var days = LocalDays()

    func todaysReviews(_ item: Item, now: Date) -> [Review] {
        let key = days.dayKey(now)
        return (item.reviews ?? []).filter { $0.day == key }.sorted { $0.at < $1.at }
    }

    /// Rates an item. A second rating on the same day replaces the first instead of compounding it.
    @discardableResult
    func rate(_ item: Item, _ rating: Rating, now: Date, settings: SchedulerSettings, session: PracticeSession?) -> Review {
        let today = todaysReviews(item, now: now)
        let base = today.first?.prevCard ?? item.card
        for r in today { ctx.delete(r) }
        let next = Scheduler(settings: settings, days: days).rate(base, rating, at: now)
        let review = Review(id: Store.newId("rv", now: now), rating: rating, at: now, day: days.dayKey(now), prev: base, next: next)
        ctx.insert(review)
        review.item = item
        review.session = session
        item.card = next
        item.updatedAt = now
        return review
    }

    /// Re-rate from "Done today": the card goes back to how it was before today's ratings.
    func rollbackToday(_ item: Item, now: Date) {
        let today = todaysReviews(item, now: now)
        guard let base = today.first?.prevCard else { return }
        for r in today { ctx.delete(r) }
        item.card = base
        item.updatedAt = now
    }

    /// Today's view of an item for the queue.
    func queueItem(_ item: Item, now: Date) -> QueueItem {
        let today = todaysReviews(item, now: now)
        return QueueItem(id: item.id, instrumentId: item.instrument?.id ?? "other", lane: item.lane,
                         paused: item.paused, reference: item.reference, card: item.card, createdAt: item.createdAt,
                         ratedToday: !today.isEmpty, startedToday: today.first?.prevCard?.isNew ?? false)
    }

    func reviewsPerDay() -> [String: Int] {
        var out: [String: Int] = [:]
        for r in (try? ctx.fetch(FetchDescriptor<Review>())) ?? [] { out[r.day, default: 0] += 1 }
        return out
    }

    func streak(now: Date) -> Int {
        PracticeStats.streak(reviewDays: Set(reviewsPerDay().keys), today: now, days: days)
    }
}
