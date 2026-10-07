import Foundation
import SustainCore
import SwiftData
import Testing
@testable import Sustain

@MainActor
struct StoreTests {
    let container: ModelContainer
    let ctx: ModelContext
    let now = Date(timeIntervalSince1970: 1_791_302_400) // 2026-10-06 12:00 UTC
    let days = LocalDays.utc

    init() throws {
        container = try Store.makeContainer(inMemory: true)
        ctx = ModelContext(container)
    }

    func guitar() throws -> Instrument {
        try #require(try ctx.fetch(FetchDescriptor<Instrument>()).first { $0.id == "guitar" })
    }

    @Test func seedsRunOnceAndADeletedSeedStaysDeleted() throws {
        try Seeder.run(ctx, now: now)
        #expect(try ctx.fetch(FetchDescriptor<Instrument>()).count == 5)
        #expect(try ctx.fetch(FetchDescriptor<Area>()).count == 19)
        let jam = try #require(AreaStore(ctx: ctx).area(id: "seed-jam"))
        _ = AreaStore(ctx: ctx).delete(jam)
        try ctx.save()
        try Seeder.run(ctx, now: now)
        #expect(try ctx.fetch(FetchDescriptor<Area>()).count == 18)
    }

    @Test func captureCreatesTheAreaOnlyWithTheItem() throws {
        try Seeder.run(ctx, now: now)
        var draft = ItemStore.Draft()
        draft.title = "  Slap groove in E "
        draft.instrument = try guitar()
        draft.pendingArea = "Slap"
        draft.link = "https://youtu.be/dQw4w9WgXcQ?t=42"
        let made = ItemStore(ctx: ctx, days: days).create(draft, media: nil, now: now)
        #expect(made.item.title == "Slap groove in E")
        #expect(made.newArea?.name == "Slap")
        #expect(made.item.area?.name == "Slap")
        #expect(made.item.youtubeId == "dQw4w9WgXcQ")
        #expect(made.item.loopA == 42)
        #expect(made.item.card.isNew)
        // Capturing again with "slaps" reuses it.
        draft.pendingArea = "slaps"
        let again = ItemStore(ctx: ctx, days: days).create(draft, media: nil, now: now)
        #expect(again.newArea == nil)
        #expect(again.item.area?.id == made.item.area?.id)
    }

    @Test func reRatingTheSameDayLeavesOneReview() throws {
        try Seeder.run(ctx, now: now)
        var draft = ItemStore.Draft()
        draft.title = "Spider exercise"
        draft.instrument = try guitar()
        let item = ItemStore(ctx: ctx, days: days).create(draft, media: nil, now: now).item
        let practice = PracticeStore(ctx: ctx, days: days)
        practice.rate(item, .again, now: now, settings: SchedulerSettings(), session: nil)
        practice.rate(item, .good, now: now.addingTimeInterval(600), settings: SchedulerSettings(), session: nil)
        let reviews = try ctx.fetch(FetchDescriptor<Review>())
        #expect(reviews.count == 1)
        #expect(reviews.first?.rating == .good)
        #expect(reviews.first?.item?.id == item.id)
        let single = Scheduler(days: days).rate(.new(at: now), .good, at: now.addingTimeInterval(600))
        #expect(item.card.stability == single.stability)
        #expect(practice.queueItem(item, now: now).startedToday)
        practice.rollbackToday(item, now: now)
        #expect(item.card.isNew)
        #expect(try ctx.fetch(FetchDescriptor<Review>()).isEmpty)
    }

    @Test func deletingAnAreaKeepsItsItemsAndUndoRestoresThem() throws {
        try Seeder.run(ctx, now: now)
        var draft = ItemStore.Draft()
        draft.title = "Minor pentatonic"
        draft.instrument = try guitar()
        draft.areaId = "seed-scale"
        let item = ItemStore(ctx: ctx, days: days).create(draft, media: nil, now: now).item
        let areas = AreaStore(ctx: ctx)
        let undo = areas.delete(try #require(areas.area(id: "seed-scale")))
        try ctx.save()
        #expect(item.area == nil)
        #expect(try ctx.fetch(FetchDescriptor<Item>()).count == 1)
        guard case .restore = areas.undo(undo) else { Issue.record("undo refused"); return }
        try ctx.save()
        #expect(item.area?.id == "seed-scale")
    }

    @Test func leavingWarmUpAfterPracticeBringsItBackTomorrow() throws {
        try Seeder.run(ctx, now: now)
        var draft = ItemStore.Draft()
        draft.title = "Lip trills"
        draft.instrument = try guitar()
        draft.lane = .warmup
        let items = ItemStore(ctx: ctx, days: days)
        let item = items.create(draft, media: nil, now: now).item
        PracticeStore(ctx: ctx, days: days).rate(item, .easy, now: now, settings: SchedulerSettings(), session: nil)
        items.setLane(item, .normal, now: now)
        #expect(days.daysBetween(now, item.card.due) == 1)
        #expect(item.warmupSince == nil)
    }

    @Test func addingMediaToAnExistingItemCopiesTheFilesAndReportsFailures() throws {
        try Seeder.run(ctx, now: now)
        let media = try MediaStore.temporary()
        defer { try? FileManager.default.removeItem(at: media.root) }
        var draft = ItemStore.Draft()
        draft.title = "It's My Life"
        draft.instrument = try guitar()
        let items = ItemStore(ctx: ctx, days: days)
        let item = items.create(draft, media: media, now: now).item
        let pdf = FileManager.default.temporaryDirectory.appending(path: "Tab-\(UUID().uuidString).pdf")
        try Data("%PDF-1.4".utf8).write(to: pdf)
        defer { try? FileManager.default.removeItem(at: pdf) }
        let missing = FileManager.default.temporaryDirectory.appending(path: "Gone-\(UUID().uuidString).pdf")

        let failed = items.add(files: [pdf, missing], pasted: [(data: Data([0x89, 0x50, 0x4E, 0x47]), ext: "png", name: "Screenshot 1")],
                               to: item, media: media, now: now)
        #expect(failed == [missing.lastPathComponent])
        let atts = (item.attachments ?? []).sorted { $0.name < $1.name }
        #expect(atts.map(\.kind) == [.image, .pdf])
        for a in atts { #expect(FileManager.default.fileExists(atPath: media.url(for: a.fileName).path)) }
        // With no media folder nothing is attached, and the file is reported instead of dropped quietly.
        #expect(items.add(files: [pdf], to: item, media: nil, now: now) == [pdf.lastPathComponent])
        #expect(item.attachments?.count == 2)
    }
}
