import Foundation
import SwiftData
import SustainCore

/// Creating and editing items.
struct ItemStore {
    let ctx: ModelContext
    var days = LocalDays()

    /// What Capture hands over when you press Add.
    struct Draft {
        var title = ""
        var instrument: Instrument?
        var areaId: String?
        /// A typed name that becomes a new area only when the item is saved.
        var pendingArea: String?
        var lane: Lane = .normal
        var notes = ""
        var link = ""
        var files: [URL] = []
        var pasted: [(data: Data, ext: String, name: String)] = []
    }

    struct Created {
        let item: Item
        let newArea: Area?
    }

    func create(_ draft: Draft, media: MediaStore?, now: Date) -> Created {
        let areas = AreaStore(ctx: ctx)
        var area = areas.area(id: draft.areaId)
        var newArea: Area?
        if let pending = draft.pendingArea, AreaNames.validate(pending) == nil {
            let made = areas.ensure(pending, now: now)
            area = made.area
            if made.created { newArea = made.area }
        }
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = Item(id: Store.newId("it", now: now), title: title, instrument: nil, area: nil, lane: draft.lane, now: now)
        ctx.insert(item)
        item.instrument = draft.instrument
        item.area = area
        item.notes = draft.notes
        let link = draft.link.trimmingCharacters(in: .whitespacesAndNewlines)
        switch LinkDetect.detect(link) {
        case .youtube:
            item.youtubeURL = link
            item.youtubeId = YouTubeLink.videoId(link)
            if let start = YouTubeLink.startSeconds(link) { item.loopA = Double(start) }
        case .pdf, .link:
            item.links = [link]
        case nil:
            break
        }
        if let media {
            for url in draft.files {
                let id = Store.newId("at", now: now)
                guard let stored = try? media.add(fileAt: url, id: id) else { continue }
                attach(Attachment(id: id, kind: MediaStore.kind(of: url), name: url.lastPathComponent,
                                  mime: MediaStore.mime(of: url), size: stored.size, fileName: stored.fileName, createdAt: now), to: item)
            }
            for p in draft.pasted {
                let id = Store.newId("at", now: now)
                guard let stored = try? media.add(data: p.data, ext: p.ext, id: id) else { continue }
                attach(Attachment(id: id, kind: .image, name: p.name, mime: "image/\(p.ext)", size: stored.size,
                                  fileName: stored.fileName, createdAt: now), to: item)
            }
        }
        return Created(item: item, newArea: newArea)
    }

    private func attach(_ a: Attachment, to item: Item) {
        ctx.insert(a)
        a.item = item
    }

    /// Lane changes go through LaneRules: leaving warm-up after practicing it there brings the item back tomorrow.
    func setLane(_ item: Item, _ lane: Lane, now: Date) {
        let out = LaneRules.changeLane(from: item.lane, to: lane, card: item.card, warmupSince: item.warmupSince, now: now, days: days)
        item.lane = lane
        item.card = out.card
        item.warmupSince = out.warmupSince
        item.updatedAt = now
    }

    func delete(_ item: Item, media: MediaStore?) {
        for a in item.attachments ?? [] { media?.remove(a.fileName) }
        ctx.delete(item)
    }
}
