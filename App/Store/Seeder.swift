import Foundation
import SwiftData
import SustainCore

/// Inserts the default instruments and the 19 seed areas once. A deleted seed is never re-added.
enum Seeder {
    static let instruments: [(id: String, name: String, color: ColorName)] = [
        ("guitar", "Guitar", .amber), ("bass", "Bass", .violet), ("piano", "Piano", .blue),
        ("drums", "Drums", .coral), ("voice", "Voice", .teal),
    ]

    static func run(_ ctx: ModelContext, now: Date = .now) throws {
        if try MetaStore(ctx: ctx).value("seededInstruments") == nil {
            let existing = Set(try ctx.fetch(FetchDescriptor<Instrument>()).map(\.id))
            for (i, s) in instruments.enumerated() where !existing.contains(s.id) {
                ctx.insert(Instrument(id: s.id, name: s.name, color: s.color, order: i, createdAt: now))
            }
            try MetaStore(ctx: ctx).set("seededInstruments", "1")
        }
        if try MetaStore(ctx: ctx).value("seededAreas") == nil {
            let existing = Set(try ctx.fetch(FetchDescriptor<Area>()).map(\.nameKey))
            for snap in AreaNames.seedAreas(now: now) where !existing.contains(snap.nameKey) {
                ctx.insert(Area(snap))
            }
            try MetaStore(ctx: ctx).set("seededAreas", "1")
        }
        try ctx.save()
    }
}

struct MetaStore {
    let ctx: ModelContext

    func value(_ key: String) throws -> String? {
        var d = FetchDescriptor<Meta>(predicate: #Predicate { $0.key == key })
        d.fetchLimit = 1
        return try ctx.fetch(d).first?.value
    }

    func set(_ key: String, _ value: String) throws {
        var d = FetchDescriptor<Meta>(predicate: #Predicate { $0.key == key })
        d.fetchLimit = 1
        if let row = try ctx.fetch(d).first {
            row.value = value
        } else {
            ctx.insert(Meta(key: key, value: value))
        }
    }
}
