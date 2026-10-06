import Foundation
import SwiftData
import SustainCore

// CloudKit-safe from day one, so iCloud sync later is a switch, not a migration:
// every property has a default, relationships are optional, and nothing uses @Attribute(.unique).
// Uniqueness (area names) is enforced by AreaStore. Enums are stored as raw values.

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Instrument.self, Area.self, Item.self, Attachment.self, Review.self, PracticeSession.self, Meta.self]
    }

    @Model
    final class Instrument {
        var id: String = ""
        var name: String = ""
        var colorRaw: String = ColorName.slate.rawValue
        var order: Int = 0
        var createdAt: Date = Date.distantPast
        @Relationship(deleteRule: .nullify, inverse: \Item.instrument)
        var items: [Item]? = []

        init(id: String, name: String, color: ColorName, order: Int, createdAt: Date) {
            self.id = id
            self.name = name
            colorRaw = color.rawValue
            self.order = order
            self.createdAt = createdAt
        }

        var color: ColorName {
            get { ColorName(rawValue: colorRaw) ?? .slate }
            set { colorRaw = newValue.rawValue }
        }
    }

    @Model
    final class Area {
        var id: String = ""
        var name: String = ""
        var nameKey: String = ""
        var colorRaw: String = ColorName.slate.rawValue
        var seedKey: String?
        var createdAt: Date = Date.distantPast
        @Relationship(deleteRule: .nullify, inverse: \Item.area)
        var items: [Item]? = []

        init(_ snap: AreaSnap) {
            id = snap.id
            name = snap.name
            nameKey = snap.nameKey
            colorRaw = snap.color.rawValue
            seedKey = snap.seedKey
            createdAt = snap.createdAt
        }

        var color: ColorName {
            get { ColorName(rawValue: colorRaw) ?? .slate }
            set { colorRaw = newValue.rawValue }
        }

        var snap: AreaSnap {
            AreaSnap(id: id, name: name, nameKey: nameKey, color: color, seedKey: seedKey, createdAt: createdAt)
        }
    }

    @Model
    final class Item {
        var id: String = ""
        var title: String = ""
        var instrument: Instrument?
        var area: Area?
        var laneRaw: String = Lane.normal.rawValue
        /// When the item last entered the warm-up lane.
        var warmupSince: Date?
        var paused: Bool = false
        var reference: Bool = false
        var artist: String = ""
        var musicalKey: String = ""
        var source: String = ""
        /// From imports only; read-only in the UI.
        var tags: [String] = []
        /// Freeform notes, plain text in v1.
        var notes: String = ""
        var links: [String] = []

        // YouTube, with the loop and speed remembered per item.
        var youtubeURL: String?
        var youtubeId: String?
        var loopA: Double?
        var loopB: Double?
        var loopOn: Bool = false
        var speed: Double = 1

        // FSRS card, stored flat so `due` can be sorted and filtered.
        var due: Date = Date.distantPast
        var stability: Double = 0
        var difficulty: Double = 0
        var elapsedDays: Int = 0
        var scheduledDays: Int = 0
        var reps: Int = 0
        var lapses: Int = 0
        var stateRaw: Int = CardState.new.rawValue
        var lastReview: Date?

        var createdAt: Date = Date.distantPast
        var updatedAt: Date = Date.distantPast

        @Relationship(deleteRule: .cascade, inverse: \Attachment.item)
        var attachments: [Attachment]? = []
        @Relationship(deleteRule: .cascade, inverse: \Review.item)
        var reviews: [Review]? = []

        init(id: String, title: String, instrument: Instrument?, area: Area?, lane: Lane, now: Date) {
            self.id = id
            self.title = title
            self.instrument = instrument
            self.area = area
            laneRaw = lane.rawValue
            warmupSince = lane == .warmup ? now : nil
            createdAt = now
            updatedAt = now
            card = .new(at: now)
        }

        var lane: Lane {
            get { Lane(rawValue: laneRaw) ?? .normal }
            set { laneRaw = newValue.rawValue }
        }

        var card: FSRSCard {
            get {
                FSRSCard(due: due, stability: stability, difficulty: difficulty, elapsedDays: elapsedDays,
                         scheduledDays: scheduledDays, reps: reps, lapses: lapses,
                         state: CardState(rawValue: stateRaw) ?? .new, lastReview: lastReview)
            }
            set {
                due = newValue.due
                stability = newValue.stability
                difficulty = newValue.difficulty
                elapsedDays = newValue.elapsedDays
                scheduledDays = newValue.scheduledDays
                reps = newValue.reps
                lapses = newValue.lapses
                stateRaw = newValue.state.rawValue
                lastReview = newValue.lastReview
            }
        }
    }

    enum AttachmentKind: String, Codable, CaseIterable {
        case image, pdf, audio, file
    }

    @Model
    final class Attachment {
        var id: String = ""
        var kindRaw: String = AttachmentKind.file.rawValue
        var name: String = ""
        var mime: String = ""
        var size: Int = 0
        /// File name inside the Media folder.
        var fileName: String = ""
        var pdfLastPage: Int?
        var isReferenceTake: Bool = false
        var createdAt: Date = Date.distantPast
        var item: Item?

        init(id: String, kind: AttachmentKind, name: String, mime: String, size: Int, fileName: String, createdAt: Date) {
            self.id = id
            kindRaw = kind.rawValue
            self.name = name
            self.mime = mime
            self.size = size
            self.fileName = fileName
            self.createdAt = createdAt
        }

        var kind: AttachmentKind { AttachmentKind(rawValue: kindRaw) ?? .file }
    }

    @Model
    final class Review {
        var id: String = ""
        var item: Item?
        var session: PracticeSession?
        var ratingRaw: Int = Rating.good.rawValue
        var at: Date = Date.distantPast
        /// Local calendar day of the rating, YYYY-MM-DD.
        var day: String = ""
        /// JSON-encoded FSRSCard before and after; the source for undo and re-rate.
        var prevCardData: Data?
        var nextCardData: Data?

        init(id: String, rating: Rating, at: Date, day: String, prev: FSRSCard, next: FSRSCard) {
            self.id = id
            ratingRaw = rating.rawValue
            self.at = at
            self.day = day
            prevCardData = try? JSONEncoder().encode(prev)
            nextCardData = try? JSONEncoder().encode(next)
        }

        var rating: Rating { Rating(rawValue: ratingRaw) ?? .good }
        var prevCard: FSRSCard? { prevCardData.flatMap { try? JSONDecoder().decode(FSRSCard.self, from: $0) } }
        var nextCard: FSRSCard? { nextCardData.flatMap { try? JSONDecoder().decode(FSRSCard.self, from: $0) } }
    }

    @Model
    final class PracticeSession {
        var id: String = ""
        var startedAt: Date = Date.distantPast
        var endedAt: Date?
        var durationSec: Int = 0
        var note: String = ""
        @Relationship(deleteRule: .nullify, inverse: \Review.session)
        var reviews: [Review]? = []

        init(id: String, startedAt: Date) {
            self.id = id
            self.startedAt = startedAt
        }
    }

    /// Key/value flags that must travel with the data (e.g. seeds already inserted).
    @Model
    final class Meta {
        var key: String = ""
        var value: String = ""

        init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }
}

typealias Instrument = SchemaV1.Instrument
typealias Area = SchemaV1.Area
typealias Item = SchemaV1.Item
typealias Attachment = SchemaV1.Attachment
typealias AttachmentKind = SchemaV1.AttachmentKind
typealias Review = SchemaV1.Review
typealias PracticeSession = SchemaV1.PracticeSession
typealias Meta = SchemaV1.Meta

enum SustainMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

enum Store {
    /// The app's container, in the sandbox's Application Support.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration("Sustain", schema: schema, isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: SustainMigrationPlan.self, configurations: [config])
    }

    static func newId(_ prefix: String, now: Date = Date()) -> String {
        prefix + "_" + String(Int(now.timeIntervalSince1970 * 1000), radix: 36) + UUID().uuidString.prefix(6).lowercased()
    }
}
