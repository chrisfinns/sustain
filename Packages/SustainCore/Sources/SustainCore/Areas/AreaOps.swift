import Foundation

/// What an area delete or merge changed, so Undo can put it back.
public struct AreaUndo: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case delete
        case merge(into: String)
    }

    public var kind: Kind
    public var area: AreaSnap
    public var itemIds: [String]
}

public enum RenameOutcome: Sendable, Equatable {
    case unchanged
    case renamed(name: String, nameKey: String)
    /// Another area already has that name: ask to merge into it.
    case askMerge(into: String)
    case problem(NameProblem)
}

public enum UndoOutcome: Sendable, Equatable {
    /// Re-add `area` and point these items back at it.
    case restore(area: AreaSnap, itemIds: [String])
    /// An area with the same name exists now; nothing is restored.
    case clash(name: String)
}

/// The rules behind every area write. The app's AreaStore applies them; nothing else writes areas.
public enum AreaOps {
    public static func rename(_ areaId: String, to text: String, areas: [AreaSnap]) -> RenameOutcome {
        guard let area = areas.first(where: { $0.id == areaId }) else { return .unchanged }
        let clean = AreaNames.cleanName(text)
        if clean.isEmpty || clean == area.name { return .unchanged }
        if let problem = AreaNames.validate(clean) { return .problem(problem) }
        let key = AreaNames.nameKey(clean)
        if let other = areas.first(where: { $0.nameKey == key && $0.id != areaId }) { return .askMerge(into: other.id) }
        return .renamed(name: clean, nameKey: key)
    }

    /// Items that lose their area when `areaId` is deleted.
    public static func delete(_ area: AreaSnap, items: [ItemAreaRef]) -> AreaUndo {
        AreaUndo(kind: .delete, area: area, itemIds: items.filter { $0.areaId == area.id }.map(\.id))
    }

    /// Items that move from `area` to `into`.
    public static func merge(_ area: AreaSnap, into dst: String, items: [ItemAreaRef]) -> AreaUndo {
        AreaUndo(kind: .merge(into: dst), area: area, itemIds: items.filter { $0.areaId == area.id }.map(\.id))
    }

    /// Undo restores only the items still where the change left them, and never creates a second area with the same name.
    public static func undo(_ u: AreaUndo, areas: [AreaSnap], items: [ItemAreaRef]) -> UndoOutcome {
        if let clash = areas.first(where: { $0.nameKey == u.area.nameKey }) { return .clash(name: clash.name) }
        let affected = Set(u.itemIds)
        let back = items.filter { it in
            guard affected.contains(it.id) else { return false }
            switch u.kind {
            case .delete: return it.areaId == nil
            case let .merge(dst): return it.areaId == dst
            }
        }.map(\.id)
        return .restore(area: u.area, itemIds: back)
    }
}
