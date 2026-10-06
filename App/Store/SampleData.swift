import Foundation
import SwiftData
import SustainCore

/// The mockup's sample items, for the `-demo` launch mode and CI screenshots. Never touches the real store.
enum SampleData {
    private struct Spec {
        var id: String
        var title: String
        var inst: String
        var area: String?
        var lane: Lane = .normal
        var artist = ""
        var key = ""
        /// nil = new; otherwise days until due (negative = overdue).
        var dueIn: Int?
        var reps = 0
        var ratedToday: Rating?
        var paused = false
        var reference = false
        var notes = ""
        var youtube: String?
    }

    static func load(_ ctx: ModelContext, now: Date = .now, days: LocalDays = LocalDays()) throws {
        try Seeder.run(ctx, now: now)
        let instruments = Dictionary(uniqueKeysWithValues: try ctx.fetch(FetchDescriptor<Instrument>()).map { ($0.id, $0) })
        let areas = try ctx.fetch(FetchDescriptor<Area>())
        func area(_ seed: String?) -> Area? {
            guard let seed else { return nil }
            if let a = areas.first(where: { $0.id == seed }) { return a }
            return AreaStore(ctx: ctx).ensure(seed, now: now).area
        }
        let specs: [Spec] = [
            Spec(id: "spider", title: "Spider exercise", inst: "guitar", area: "seed-technique", lane: .warmup, dueIn: 0, reps: 21,
                 notes: "Keep fingers close to the frets.\nAlternate picking, no gaps between strings."),
            Spec(id: "trills", title: "Lip trills, 5-note scale", inst: "voice", lane: .warmup, dueIn: 0, reps: 14, notes: "Steady air, loose jaw."),
            Spec(id: "wing", title: "Little Wing intro", inst: "guitar", area: "seed-repertoire", lane: .focus, artist: "Jimi Hendrix", key: "Em", dueIn: -2, reps: 7,
                 notes: "Thumb over the neck for the bass notes. Let the double-stops ring into each other.\n\nBars 3–4 are the hard part: loop them slow before speeding up.\n\nTeacher, Sep 28: \"relax the fretting hand between phrases.\"",
                 youtube: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"),
            Spec(id: "para", title: "Paradiddle-diddle", inst: "drums", area: "seed-rudiment", lane: .focus, dueIn: 0, reps: 9, notes: "Accent on 1 only. Even stick heights."),
            Spec(id: "penta", title: "Minor pentatonic, box 1", inst: "guitar", area: "seed-scale", key: "A", dueIn: -5, reps: 12),
            Spec(id: "two5", title: "ii–V–I voicings in B♭", inst: "piano", area: "seed-voicing", key: "B♭", dueIn: 0, reps: 5),
            Spec(id: "hyst", title: "Hysteria intro", inst: "bass", area: "seed-repertoire", artist: "Muse"),
            Spec(id: "walk", title: "Walking line over F blues", inst: "bass", area: "seed-walking-line"),
            Spec(id: "moon", title: "Moonlight Sonata, bars 1–16", inst: "piano", area: "seed-repertoire", artist: "Beethoven"),
            Spec(id: "breath", title: "Breathing: 4 in, 8 out", inst: "voice"),
            Spec(id: "three", title: "Major scale, 3 notes per string", inst: "guitar", area: "seed-scale", dueIn: 0, reps: 15, ratedToday: .good),
            Spec(id: "money", title: "Money beat with ghost notes", inst: "drums", area: "seed-groove", dueIn: 0, reps: 6, ratedToday: .hard),
            Spec(id: "ivls", title: "Interval ID: 3rds vs 4ths", inst: "guitar", area: "seed-ear-training", dueIn: 8, reps: 10),
            Spec(id: "seven", title: "Seven Nation Army riff", inst: "guitar", area: "Gig set", artist: "The White Stripes", dueIn: 41, reps: 11),
            Spec(id: "moby", title: "Moby Dick fill", inst: "drums", area: "seed-fill", artist: "Led Zeppelin", dueIn: -20, reps: 3, paused: true),
            Spec(id: "chart", title: "Open chord chart", inst: "guitar", area: "seed-chord", reference: true),
        ]
        let scheduler = Scheduler(days: days)
        for (i, s) in specs.enumerated() {
            let created = now.addingTimeInterval(Double(i - 100) * 86_400)
            let item = Item(id: "demo-" + s.id, title: s.title, instrument: nil, area: nil, lane: s.lane, now: created)
            ctx.insert(item)
            item.instrument = instruments[s.inst]
            item.area = area(s.area)
            item.artist = s.artist
            item.musicalKey = s.key
            item.notes = s.notes
            item.paused = s.paused
            item.reference = s.reference
            if let url = s.youtube {
                item.youtubeURL = url
                item.youtubeId = YouTubeLink.videoId(url)
                item.loopA = 42
                item.loopB = 68
                item.speed = 0.75
            }
            if let dueIn = s.dueIn {
                let interval = max(3, s.reps)
                let last = days.addDays(dueIn - interval, to: now)
                item.card = FSRSCard(due: days.addDays(dueIn, to: now), stability: Double(interval), difficulty: 5.5,
                                     elapsedDays: interval, scheduledDays: interval, reps: s.reps, lapses: 0, state: .review, lastReview: last)
            }
            if let r = s.ratedToday {
                let before = item.card
                let after = scheduler.rate(before, r, at: now.addingTimeInterval(-3600))
                let review = Review(id: "demo-rv-" + s.id, rating: r, at: now.addingTimeInterval(-3600), day: days.dayKey(now), prev: before, next: after)
                ctx.insert(review)
                review.item = item
                item.card = after
            }
        }
        // A few past days of practice so the streak shows.
        for d in 1...8 {
            let at = days.addDays(-d, to: now)
            let r = Review(id: "demo-past-\(d)", rating: .good, at: at, day: days.dayKey(at), prev: .new(at: at), next: .new(at: at))
            ctx.insert(r)
        }
        try ctx.save()
    }
}
