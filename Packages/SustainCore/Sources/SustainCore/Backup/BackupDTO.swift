import Foundation

/// The backup file format, version 1. Plain Codable values, independent of the database.
/// M0 writes it as JSON; M3 wraps it in a .sustain zip together with the media files.
public struct BackupV1: Codable, Sendable, Equatable {
    public static let currentVersion = 1

    public var version = BackupV1.currentVersion
    public var exportedAt: Date
    public var settings: Settings
    public var instruments: [Instrument]
    public var areas: [Area]
    public var items: [Item]
    public var reviews: [Review]
    public var sessions: [Session]
    public var meta: [String: String]

    public init(exportedAt: Date, settings: Settings, instruments: [Instrument], areas: [Area], items: [Item],
                reviews: [Review], sessions: [Session], meta: [String: String]) {
        self.exportedAt = exportedAt
        self.settings = settings
        self.instruments = instruments
        self.areas = areas
        self.items = items
        self.reviews = reviews
        self.sessions = sessions
        self.meta = meta
    }

    public struct Settings: Codable, Sendable, Equatable {
        public var retention: Double
        public var maxInterval: Int
        public var newPerDay: Int
        public var simple: Bool
        public var mode: String

        public init(retention: Double, maxInterval: Int, newPerDay: Int, simple: Bool, mode: String) {
            self.retention = retention
            self.maxInterval = maxInterval
            self.newPerDay = newPerDay
            self.simple = simple
            self.mode = mode
        }
    }

    public struct Instrument: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var color: ColorName
        public var order: Int
        public var createdAt: Date

        public init(id: String, name: String, color: ColorName, order: Int, createdAt: Date) {
            self.id = id
            self.name = name
            self.color = color
            self.order = order
            self.createdAt = createdAt
        }
    }

    public struct Area: Codable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var color: ColorName
        public var seedKey: String?
        public var createdAt: Date

        public init(id: String, name: String, color: ColorName, seedKey: String?, createdAt: Date) {
            self.id = id
            self.name = name
            self.color = color
            self.seedKey = seedKey
            self.createdAt = createdAt
        }
    }

    public struct YouTube: Codable, Sendable, Equatable {
        public var url: String
        public var videoId: String
        public var loopA: Double?
        public var loopB: Double?
        public var loopOn: Bool
        public var speed: Double

        public init(url: String, videoId: String, loopA: Double?, loopB: Double?, loopOn: Bool, speed: Double) {
            self.url = url
            self.videoId = videoId
            self.loopA = loopA
            self.loopB = loopB
            self.loopOn = loopOn
            self.speed = speed
        }
    }

    public struct Attachment: Codable, Sendable, Equatable {
        public var id: String
        public var kind: String
        public var name: String
        public var mime: String
        public var size: Int
        /// Path inside the archive's media folder (M3); in a JSON-only backup the file isn't included.
        public var fileName: String
        public var pdfLastPage: Int?
        public var isReferenceTake: Bool
        public var createdAt: Date

        public init(id: String, kind: String, name: String, mime: String, size: Int, fileName: String,
                    pdfLastPage: Int?, isReferenceTake: Bool, createdAt: Date) {
            self.id = id
            self.kind = kind
            self.name = name
            self.mime = mime
            self.size = size
            self.fileName = fileName
            self.pdfLastPage = pdfLastPage
            self.isReferenceTake = isReferenceTake
            self.createdAt = createdAt
        }
    }

    public struct Item: Codable, Sendable, Equatable {
        public var id: String
        public var title: String
        public var instrumentId: String?
        public var areaId: String?
        public var lane: Lane
        public var warmupSince: Date?
        public var paused: Bool
        public var reference: Bool
        public var artist: String
        public var key: String
        public var source: String
        public var tags: [String]
        public var notes: String
        public var links: [String]
        public var youtube: YouTube?
        public var card: FSRSCard
        public var attachments: [Attachment]
        public var createdAt: Date
        public var updatedAt: Date

        public init(id: String, title: String, instrumentId: String?, areaId: String?, lane: Lane, warmupSince: Date?,
                    paused: Bool, reference: Bool, artist: String, key: String, source: String, tags: [String],
                    notes: String, links: [String], youtube: YouTube?, card: FSRSCard, attachments: [Attachment],
                    createdAt: Date, updatedAt: Date) {
            self.id = id
            self.title = title
            self.instrumentId = instrumentId
            self.areaId = areaId
            self.lane = lane
            self.warmupSince = warmupSince
            self.paused = paused
            self.reference = reference
            self.artist = artist
            self.key = key
            self.source = source
            self.tags = tags
            self.notes = notes
            self.links = links
            self.youtube = youtube
            self.card = card
            self.attachments = attachments
            self.createdAt = createdAt
            self.updatedAt = updatedAt
        }
    }

    public struct Review: Codable, Sendable, Equatable {
        public var id: String
        public var itemId: String
        public var sessionId: String?
        public var rating: Rating
        public var at: Date
        public var day: String
        public var prevCard: FSRSCard?
        public var nextCard: FSRSCard?

        public init(id: String, itemId: String, sessionId: String?, rating: Rating, at: Date, day: String,
                    prevCard: FSRSCard?, nextCard: FSRSCard?) {
            self.id = id
            self.itemId = itemId
            self.sessionId = sessionId
            self.rating = rating
            self.at = at
            self.day = day
            self.prevCard = prevCard
            self.nextCard = nextCard
        }
    }

    public struct Session: Codable, Sendable, Equatable {
        public var id: String
        public var startedAt: Date
        public var endedAt: Date?
        public var durationSec: Int
        public var note: String

        public init(id: String, startedAt: Date, endedAt: Date?, durationSec: Int, note: String) {
            self.id = id
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.durationSec = durationSec
            self.note = note
        }
    }

    /// ISO 8601 dates with milliseconds, readable and exact enough to round-trip schedules.
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .custom { date, encoder in
            var c = encoder.singleValueContainer()
            try c.encode(date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
        }
        return e
    }

    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            let s = try c.decode(String.self)
            if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(s) { return date }
            return try Date.ISO8601FormatStyle().parse(s)
        }
        return d
    }
}
