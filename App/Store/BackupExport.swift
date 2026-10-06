import Foundation
import SwiftData
import SustainCore
import SwiftUI
import UniformTypeIdentifiers

/// M0 backup: everything except media files, as one JSON file.
enum BackupExport {
    static func make(_ ctx: ModelContext, settings: AppSettings, now: Date = .now) throws -> Data {
        let instruments = try ctx.fetch(FetchDescriptor<Instrument>())
        let areas = try ctx.fetch(FetchDescriptor<Area>())
        let items = try ctx.fetch(FetchDescriptor<Item>())
        let reviews = try ctx.fetch(FetchDescriptor<Review>())
        let sessions = try ctx.fetch(FetchDescriptor<PracticeSession>())
        let meta = try ctx.fetch(FetchDescriptor<Meta>())
        let backup = BackupV1(
            exportedAt: now,
            settings: .init(retention: settings.retention, maxInterval: settings.maxInterval, newPerDay: settings.newPerDay,
                            simple: settings.simple, mode: settings.mode.rawValue),
            instruments: instruments.map { .init(id: $0.id, name: $0.name, color: $0.color, order: $0.order, createdAt: $0.createdAt) },
            areas: areas.map { .init(id: $0.id, name: $0.name, color: $0.color, seedKey: $0.seedKey, createdAt: $0.createdAt) },
            items: items.map { it in
                BackupV1.Item(
                    id: it.id, title: it.title, instrumentId: it.instrument?.id, areaId: it.area?.id, lane: it.lane,
                    warmupSince: it.warmupSince, paused: it.paused, reference: it.reference, artist: it.artist,
                    key: it.musicalKey, source: it.source, tags: it.tags, notes: it.notes, links: it.links,
                    youtube: it.youtubeId.map { .init(url: it.youtubeURL ?? "", videoId: $0, loopA: it.loopA, loopB: it.loopB, loopOn: it.loopOn, speed: it.speed) },
                    card: it.card,
                    attachments: (it.attachments ?? []).map {
                        .init(id: $0.id, kind: $0.kindRaw, name: $0.name, mime: $0.mime, size: $0.size, fileName: $0.fileName,
                              pdfLastPage: $0.pdfLastPage, isReferenceTake: $0.isReferenceTake, createdAt: $0.createdAt)
                    },
                    createdAt: it.createdAt, updatedAt: it.updatedAt)
            },
            reviews: reviews.compactMap { r in
                guard let itemId = r.item?.id else { return nil }
                return .init(id: r.id, itemId: itemId, sessionId: r.session?.id, rating: r.rating, at: r.at, day: r.day,
                             prevCard: r.prevCard, nextCard: r.nextCard)
            },
            sessions: sessions.map { .init(id: $0.id, startedAt: $0.startedAt, endedAt: $0.endedAt, durationSec: $0.durationSec, note: $0.note) },
            meta: Dictionary(meta.map { ($0.key, $0.value) }, uniquingKeysWith: { a, _ in a }))
        return try BackupV1.encoder().encode(backup)
    }

    static func fileName(now: Date = .now) -> String {
        "sustain-backup-\(LocalDays().dayKey(now)).json"
    }
}

/// Wraps the JSON for SwiftUI's file exporter.
nonisolated struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
