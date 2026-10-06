import Foundation

public struct AreaSnap: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
    public var nameKey: String
    public var color: ColorName
    public var seedKey: String?
    public var createdAt: Date

    public init(id: String, name: String, nameKey: String? = nil, color: ColorName, seedKey: String? = nil, createdAt: Date) {
        self.id = id
        self.name = name
        self.nameKey = nameKey ?? AreaNames.nameKey(name)
        self.color = color
        self.seedKey = seedKey
        self.createdAt = createdAt
    }
}

/// The area and instrument of an item: all the area rules need.
public struct ItemAreaRef: Sendable, Equatable {
    public var id: String
    public var areaId: String?
    public var instrumentId: String

    public init(id: String, areaId: String?, instrumentId: String) {
        self.id = id
        self.areaId = areaId
        self.instrumentId = instrumentId
    }
}

public enum NameProblem: String, Sendable, Equatable {
    case empty, noLetters, reserved

    public var text: String {
        switch self {
        case .empty: "Type a name"
        case .noLetters: "Use a letter, number or emoji"
        case .reserved: "That name is used by a filter"
        }
    }
}

public enum AreaNames {
    public static let maxLength = 32

    private static let separators: Set<Character> = ["-", "–", "—", "_", "/", "&", ".", ",", ":", ";", "'", "\"", "(", ")", "!", "?"]

    /// Case, punctuation and a trailing plural "s" fold together; musical symbols do not (♯ = #, ♭ = b).
    /// "Warm-Up" = "warm ups", "Techniques" = "Technique", "B♭ voicings" = "Bb voicings", "C# major" ≠ "C major".
    public static func nameKey(_ name: String) -> String {
        let folded = name.precomposedStringWithCompatibilityMapping.lowercased()
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
        var words: [String] = []
        var word = ""
        for ch in folded {
            if ch.isWhitespace || separators.contains(ch) {
                if !word.isEmpty { words.append(word); word = "" }
            } else {
                word.append(ch)
            }
        }
        if !word.isEmpty { words.append(word) }
        guard var last = words.last else { return "" }
        if last.count >= 3 && last.hasSuffix("s") && !last.hasSuffix("ss") {
            last.removeLast()
            words[words.count - 1] = last
        }
        return words.joined(separator: " ")
    }

    /// Collapses whitespace, trims, and cuts to `max` characters.
    public static func cleanName(_ name: String, max: Int = maxLength) -> String {
        let collapsed = name.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return String(collapsed.prefix(max))
    }

    /// True for keys like "warm up", "warmup", "daily warm up".
    public static func isWarmupKey(_ key: String) -> Bool {
        let words = key.split(separator: " ")
        for (i, w) in words.enumerated() {
            if w == "warmup" { return true }
            if w == "warm", i + 1 < words.count, words[i + 1] == "up" { return true }
        }
        return false
    }

    /// Names the Library filter uses.
    public static func isReservedKey(_ key: String) -> Bool {
        key == "no area" || key == "all area"
    }

    public static func validate(_ name: String) -> NameProblem? {
        if cleanName(name).isEmpty { return .empty }
        let key = nameKey(name)
        if key.isEmpty { return .noLetters }
        if isReservedKey(key) { return .reserved }
        return nil
    }

    /// "Walking Lines" → "walking-line"
    public static func slug(_ name: String) -> String {
        var out = ""
        var dash = false
        for ch in nameKey(name) {
            if ch.isASCII && (ch.isLetter || ch.isNumber) || ch == "#" {
                if dash && !out.isEmpty { out.append("-") }
                out.append(ch)
                dash = false
            } else {
                dash = true
            }
        }
        return out
    }

    // MARK: - Seeds

    /// Inserted once, never re-added after a delete.
    public static let seedNames = [
        "Repertoire", "Technique", "Ear Training", "Transcription", "Songwriting", "Scales", "Chords", "Licks", "Fretboard",
        "Jam", "Grooves", "Walking Lines", "Voicings", "Sight-Reading", "Rudiments", "Fills", "Independence", "Lyrics", "Range & Breath",
    ]

    /// Day-one chip order per instrument (seed keys). After that, usage outranks it.
    public static let seedSuggest: [String: [String]] = [
        "guitar": ["repertoire", "chord", "scale", "lick", "technique", "ear-training"],
        "bass": ["repertoire", "groove", "scale", "walking-line", "technique", "ear-training"],
        "piano": ["repertoire", "voicing", "scale", "sight-reading", "technique", "ear-training"],
        "drums": ["repertoire", "rudiment", "groove", "fill", "independence", "technique"],
        "voice": ["repertoire", "range-breath", "lyric", "technique", "ear-training", "songwriting"],
        "other": ["repertoire", "technique", "ear-training", "transcription", "songwriting"],
    ]

    public static func seedAreas(now: Date) -> [AreaSnap] {
        seedNames.enumerated().map { i, name in
            let s = slug(name)
            return AreaSnap(id: "seed-" + s, name: name, color: ColorName.allCases[i % ColorName.allCases.count],
                            seedKey: s, createdAt: now.addingTimeInterval(Double(i) / 1000))
        }
    }

    /// A new area id: "ar_" + time + random, sortable by creation.
    public static func newId(now: Date = Date()) -> String {
        let ms = Int(now.timeIntervalSince1970 * 1000)
        let rand = (0..<6).map { _ in "0123456789abcdefghijklmnopqrstuvwxyz".randomElement()! }
        return "ar_" + String(ms, radix: 36) + String(rand)
    }

    /// The existing area with the same key, or a new one with the least-used color. Nothing is saved here.
    public static func makeArea(_ name: String, areas: [AreaSnap], now: Date, id: String? = nil) -> (area: AreaSnap, isNew: Bool) {
        let clean = cleanName(name)
        let key = nameKey(clean)
        if let existing = areas.first(where: { $0.nameKey == key }) { return (existing, false) }
        let area = AreaSnap(id: id ?? newId(now: now), name: clean, nameKey: key,
                            color: ColorName.leastUsed(areas.map(\.color)), createdAt: now)
        return (area, true)
    }

    /// Stable alphabetical order for lists.
    public static func ordered(_ areas: [AreaSnap]) -> [AreaSnap] {
        areas.sorted {
            let (a, b) = ($0.name.lowercased(), $1.name.lowercased())
            return a != b ? a < b : $0.id < $1.id
        }
    }
}
