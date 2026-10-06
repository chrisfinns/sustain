import Foundation
import Testing
@testable import SustainCore

private struct FSRSFixture: Decodable {
    struct Card: Decodable {
        let due: Int64
        let stability: Double
        let difficulty: Double
        let elapsed_days: Int
        let scheduled_days: Int
        let reps: Int
        let lapses: Int
        let state: Int
        let last_review: Int64?

        var card: FSRSCard {
            FSRSCard(due: date(ms: due), stability: stability, difficulty: difficulty, elapsedDays: elapsed_days,
                     scheduledDays: scheduled_days, reps: reps, lapses: lapses, state: CardState(rawValue: state)!,
                     lastReview: last_review.map { date(ms: $0) })
        }
    }

    struct Step: Decodable {
        let at: Int64
        let rating: Int
        let card: Card
    }

    struct Case: Decodable {
        let retention: Double
        let maxInterval: Int
        let initial: Card
        let steps: [Step]
    }

    let cases: [Case]
}

@Suite struct FSRSParityTests {
    @Test func matchesTsFsrsGoldenCases() throws {
        let fx = try JSONDecoder().decode(FSRSFixture.self, from: try fixture("fsrs-cases"))
        #expect(fx.cases.count == 200)
        var mismatches: [String] = []
        var steps = 0
        for (n, c) in fx.cases.enumerated() {
            let engine = FSRS(retention: c.retention, maximumInterval: c.maxInterval)
            var card = c.initial.card
            for (i, step) in c.steps.enumerated() {
                steps += 1
                card = engine.next(card, at: date(ms: step.at), rating: Rating(rawValue: step.rating)!, days: .utc)
                let e = step.card
                let same = abs(card.stability - e.stability) < 1e-6
                    && abs(card.difficulty - e.difficulty) < 1e-6
                    && ms(card.due) == e.due
                    && card.scheduledDays == e.scheduled_days
                    && card.elapsedDays == e.elapsed_days
                    && card.reps == e.reps
                    && card.lapses == e.lapses
                    && card.state.rawValue == e.state
                    && card.lastReview.map(ms) == e.last_review
                if !same {
                    mismatches.append("case \(n) step \(i) r=\(step.rating): got S=\(card.stability) D=\(card.difficulty) ivl=\(card.scheduledDays) elapsed=\(card.elapsedDays) lapses=\(card.lapses); want S=\(e.stability) D=\(e.difficulty) ivl=\(e.scheduled_days) elapsed=\(e.elapsed_days) lapses=\(e.lapses)")
                    card = e.card // resync so one miss doesn't cascade
                }
            }
        }
        #expect(steps > 1000)
        #expect(mismatches.isEmpty, "\(mismatches.count) mismatches:\n\(mismatches.prefix(12).joined(separator: "\n"))")
    }
}

@Suite struct SchedulerTests {
    let now = date("2026-10-06T15:00:00Z")
    let scheduler = Scheduler(days: utcDays)

    @Test func newCardRatedGoodComesBackInAtLeastADay() {
        let card = scheduler.rate(.new(at: now), .good, at: now)
        #expect(utcDays.daysBetween(now, card.due) >= 1)
        #expect(card.state == .review)
        #expect(card.reps == 1)
    }

    @Test func againShortensAndEasyLengthens() {
        var card = FSRSCard.new(at: now)
        var t = now
        card = scheduler.rate(card, .good, at: t)
        t = card.due
        let p = scheduler.preview(card, at: t)
        #expect(p[.again]! < p[.hard]!)
        #expect(p[.hard]! < p[.good]!)
        #expect(p[.good]! < p[.easy]!)
    }

    @Test(arguments: [30, 60, 120])
    func neverSchedulesPastTheLongestGap(maxInterval: Int) {
        let s = Scheduler(settings: SchedulerSettings(retention: 0.9, maxInterval: maxInterval), days: utcDays)
        var rng = SplitMix(seed: 42)
        for _ in 0..<40 {
            var card = FSRSCard.new(at: now)
            var t = now
            for _ in 0..<25 {
                let r = Rating(rawValue: Int(rng.next() % 4) + 1)!
                card = s.rate(card, r, at: t)
                #expect(utcDays.daysBetween(t, card.due) <= maxInterval)
                #expect(card.scheduledDays <= maxInterval)
                for d in s.preview(card, at: card.due).values { #expect(d <= maxInterval) }
                t = utcDays.addDays(Int(rng.next() % 5), to: card.due)
            }
        }
    }

    @Test func reRatingFromThePreviousCardEqualsASingleRating() {
        let before = scheduler.rate(.new(at: now), .good, at: now)
        let later = before.due
        let single = scheduler.rate(before, .good, at: later)
        // Rating twice compounds...
        let compounded = scheduler.rate(scheduler.rate(before, .again, at: later), .good, at: later.addingTimeInterval(600))
        #expect(compounded.stability != single.stability)
        // ...so a same-day re-rate starts again from the card before the first rating.
        let reRated = scheduler.rate(before, .good, at: later.addingTimeInterval(600))
        #expect(reRated.stability == single.stability)
        #expect(reRated.scheduledDays == single.scheduledDays)
    }

    @Test func simpleModeUsesAgainAndGood() {
        #expect(Rating.simple == [.again, .good])
    }

    @Test func labels() {
        #expect(Scheduler.intervalLabel(1) == "1d")
        #expect(Scheduler.intervalLabel(13) == "13d")
        #expect(Scheduler.intervalLabel(14) == "2w")
        #expect(Scheduler.intervalLabel(55) == "8w")
        #expect(Scheduler.intervalLabel(60) == "2mo")
        #expect(Scheduler.nextLabel(0) == "today")
        #expect(Scheduler.nextLabel(1) == "tomorrow")
        #expect(Scheduler.nextLabel(12) == "in 12d")
    }

    @Test func stages() {
        #expect(scheduler.stage(of: .new(at: now)) == .new)
        let first = scheduler.rate(.new(at: now), .good, at: now)
        #expect(scheduler.stage(of: first) == .learning)
        var long = first
        long.scheduledDays = 20
        #expect(scheduler.stage(of: long) == .review)
        long.scheduledDays = 60
        #expect(scheduler.stage(of: long) == .mastered)
    }
}

/// Small deterministic RNG for tests.
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
