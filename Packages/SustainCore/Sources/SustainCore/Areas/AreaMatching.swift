import Foundation

public enum AreaMatchRow: Sendable, Equatable {
    /// "Make this a daily warm-up": sets the lane instead of creating an area.
    case warmup
    /// tier 0 exact, 1 prefix, 2 substring, 3 typo
    case area(id: String, name: String, tier: Int)
    case create(name: String)

    public var label: String {
        switch self {
        case .warmup: "Make this a daily warm-up"
        case let .area(_, name, _): name
        case let .create(name): "Create \"\(name)\""
        }
    }
}

public struct AreaMatchResult: Sendable, Equatable {
    public var rows: [AreaMatchRow]
    /// The row Enter picks when nothing is highlighted.
    public var defaultIndex: Int?
    public var problem: NameProblem?
}

public enum AreaMatching {
    /// Suggestions for typed text: warm-up row, matches (exact, prefix, substring, typo; max 6), then Create.
    public static func match(_ query: String, areas: [AreaSnap]) -> AreaMatchResult {
        let q = AreaNames.cleanName(query)
        guard !q.isEmpty else { return AreaMatchResult(rows: [], defaultIndex: nil, problem: nil) }
        let key = AreaNames.nameKey(q)
        var rows: [AreaMatchRow] = []
        let warm = AreaNames.isWarmupKey(key)
        if warm { rows.append(.warmup) }
        let problem = AreaNames.validate(q)
        var scored: [(area: AreaSnap, tier: Int)] = []
        if !key.isEmpty {
            let order = Dictionary(uniqueKeysWithValues: AreaNames.ordered(areas).enumerated().map { ($1.id, $0) })
            for a in areas {
                let k = a.nameKey
                let tier = k == key ? 0 : k.hasPrefix(key) ? 1 : k.contains(key) ? 2 : typoNear(key, k) ? 3 : 9
                if tier < 9 { scored.append((a, tier)) }
            }
            scored.sort { $0.tier != $1.tier ? $0.tier < $1.tier : order[$0.area.id]! < order[$1.area.id]! }
            scored = Array(scored.prefix(6))
        }
        rows += scored.map { AreaMatchRow.area(id: $0.area.id, name: $0.area.name, tier: $0.tier) }
        let exact = scored.contains { $0.tier == 0 }
        if !exact && problem == nil { rows.append(.create(name: q)) }

        var defaultIndex: Int?
        if warm {
            defaultIndex = 0
        } else {
            let strong = rows.firstIndex { if case let .area(_, _, t) = $0 { return t <= 1 }; return false }
            let typo = rows.firstIndex { if case let .area(_, _, t) = $0 { return t == 3 }; return false }
            let create = rows.firstIndex { if case .create = $0 { return true }; return false }
            defaultIndex = strong ?? typo ?? create
        }
        return AreaMatchResult(rows: rows, defaultIndex: defaultIndex, problem: problem == .empty ? nil : problem)
    }

    /// Optimal string alignment distance (Damerau-Levenshtein with adjacent swaps).
    public static func osa(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var d = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { d[i][0] = i }
        for j in 0...b.count { d[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                d[i][j] = min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost)
                if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] {
                    d[i][j] = min(d[i][j], d[i - 2][j - 2] + 1)
                }
            }
        }
        return d[a.count][b.count]
    }

    static func typoNear(_ q: String, _ key: String) -> Bool {
        if key.count < 4 || q.count < 3 { return false }
        return osa(q, key) <= (key.count >= 8 ? 2 : 1)
    }

    /// "Mostly Guitar" / "Unused" hint per area: the instrument it's used on most, or nil when unused.
    public static func topInstrument(areaId: String, items: [ItemAreaRef]) -> String? {
        var counts: [String: Int] = [:]
        for it in items where it.areaId == areaId { counts[it.instrumentId, default: 0] += 1 }
        return counts.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key
    }
}

public enum AreaRanking {
    public static let maxChips = 6

    /// Up to 6 chips for an instrument: most used there, then seed suggestions, then unused custom areas.
    /// The selected area is always shown, first if it wasn't already there.
    public static func rankForCapture(areas: [AreaSnap], items: [ItemAreaRef], instrumentId: String, selectedId: String?) -> [String] {
        var here: [String: Int] = [:]
        var anywhere: [String: Int] = [:]
        for it in items {
            guard let a = it.areaId else { continue }
            anywhere[a, default: 0] += 1
            if it.instrumentId == instrumentId { here[a, default: 0] += 1 }
        }
        let used = areas.filter { here[$0.id] != nil }
            .sorted { here[$0.id]! != here[$1.id]! ? here[$0.id]! > here[$1.id]! : $0.createdAt < $1.createdAt }
            .map(\.id)
        let suggest = (AreaNames.seedSuggest[instrumentId] ?? AreaNames.seedSuggest["other"]!)
            .compactMap { key in areas.first { $0.seedKey == key }?.id }
        let fresh = areas.filter { $0.seedKey == nil && anywhere[$0.id] == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.id)
        var out: [String] = []
        for id in used + suggest + fresh where !out.contains(id) { out.append(id) }
        return pinFirst(Array(out.prefix(maxChips)), selectedId)
    }

    public static func pinFirst(_ ids: [String], _ id: String?, max: Int = maxChips) -> [String] {
        guard let id, !ids.contains(id) else { return ids }
        return Array(([id] + ids).prefix(max))
    }
}
