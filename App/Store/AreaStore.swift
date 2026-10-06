import Foundation
import SwiftData
import SustainCore

/// The only place that writes areas. The rules live in SustainCore's AreaOps; this applies them to the store.
struct AreaStore {
    let ctx: ModelContext

    func all() -> [Area] {
        let areas = (try? ctx.fetch(FetchDescriptor<Area>())) ?? []
        let order = AreaNames.ordered(areas.map(\.snap)).map(\.id)
        return order.compactMap { id in areas.first { $0.id == id } }
    }

    func area(id: String?) -> Area? {
        guard let id else { return nil }
        var d = FetchDescriptor<Area>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? ctx.fetch(d).first
    }

    func itemRefs() -> [ItemAreaRef] {
        ((try? ctx.fetch(FetchDescriptor<Item>())) ?? []).map {
            ItemAreaRef(id: $0.id, areaId: $0.area?.id, instrumentId: $0.instrument?.id ?? "other")
        }
    }

    /// The existing area with this name, or a new one. Call it only when saving the item that uses it,
    /// so a cancelled capture leaves no orphan area.
    func ensure(_ name: String, now: Date) -> (area: Area, created: Bool) {
        let made = AreaNames.makeArea(name, areas: all().map(\.snap), now: now)
        if !made.isNew, let existing = area(id: made.area.id) { return (existing, false) }
        let row = Area(made.area)
        ctx.insert(row)
        return (row, true)
    }

    enum AddResult {
        case added(Area)
        case existing(Area)
        case problem(NameProblem)
    }

    func add(_ name: String, now: Date) -> AddResult {
        if let problem = AreaNames.validate(name) { return .problem(problem) }
        let made = ensure(name, now: now)
        return made.created ? .added(made.area) : .existing(made.area)
    }

    /// Applies a plain rename. A name clash comes back as `.askMerge` for the UI to confirm.
    func rename(_ area: Area, to text: String) -> RenameOutcome {
        let outcome = AreaOps.rename(area.id, to: text, areas: all().map(\.snap))
        if case let .renamed(name, key) = outcome {
            area.name = name
            area.nameKey = key
        }
        return outcome
    }

    func cycleColor(_ area: Area) {
        area.color = area.color.next
    }

    func merge(_ src: Area, into dst: Area) -> AreaUndo {
        let undo = AreaOps.merge(src.snap, into: dst.id, items: itemRefs())
        for item in src.items ?? [] { item.area = dst }
        ctx.delete(src)
        return undo
    }

    func delete(_ area: Area) -> AreaUndo {
        let undo = AreaOps.delete(area.snap, items: itemRefs())
        for item in area.items ?? [] { item.area = nil }
        ctx.delete(area)
        return undo
    }

    func undo(_ u: AreaUndo) -> UndoOutcome {
        let outcome = AreaOps.undo(u, areas: all().map(\.snap), items: itemRefs())
        if case let .restore(snap, itemIds) = outcome {
            let row = Area(snap)
            ctx.insert(row)
            let ids = Set(itemIds)
            for item in (try? ctx.fetch(FetchDescriptor<Item>())) ?? [] where ids.contains(item.id) {
                item.area = row
            }
        }
        return outcome
    }
}
