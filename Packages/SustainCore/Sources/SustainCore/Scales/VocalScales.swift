import Foundation

/// A piano-led vocal exercise: the piano gives the key with a chord, plays the pattern for you to sing along,
/// then moves a half step and goes again, across the starting notes you pick.
public struct ScaleExercise: Codable, Equatable, Sendable {
    public var pattern: ScalePattern
    /// Lowest and highest starting note, as MIDI note numbers (60 = C4).
    public private(set) var low: Int
    public private(set) var high: Int
    public var direction: ScaleDirection
    public var speed: ScaleSpeed

    /// Starting notes stay between C2 and C5, so the top of an octave pattern is still on a full piano.
    public static let rootRange = 36...72

    public init(pattern: ScalePattern = .fiveNote, low: Int = 48, high: Int = 55,
                direction: ScaleDirection = .upAndDown, speed: ScaleSpeed = .medium) {
        self.pattern = pattern
        self.direction = direction
        self.speed = speed
        self.low = Self.clamp(min(low, high))
        self.high = Self.clamp(max(low, high))
    }

    /// Decoding goes through the same clamps, so an old or hand-edited value can't produce a broken range.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(pattern: try c.decode(ScalePattern.self, forKey: .pattern),
                  low: try c.decode(Int.self, forKey: .low), high: try c.decode(Int.self, forKey: .high),
                  direction: try c.decode(ScaleDirection.self, forKey: .direction),
                  speed: try c.decode(ScaleSpeed.self, forKey: .speed))
    }

    /// Moving one end past the other drags it along, so the range never turns inside out.
    public mutating func setLow(_ note: Int) {
        low = Self.clamp(note)
        if high < low { high = low }
    }

    public mutating func setHigh(_ note: Int) {
        high = Self.clamp(note)
        if low > high { low = high }
    }

    /// The starting note of each round, in the order they're played.
    public var roots: [Int] {
        let up = Array(low...high)
        switch direction {
        case .up: return up
        case .down: return up.reversed()
        case .upAndDown: return up + up.dropLast().reversed()
        }
    }

    /// Each round: the chord for two beats, the pattern one beat a note with the last held for two, then a beat to breathe.
    public var notes: [ScaleNote] {
        let beat = speed.beat
        var out: [ScaleNote] = []
        var t = 0.0
        for (round, root) in roots.enumerated() {
            if round > 0 { t += beat }
            out.append(ScaleNote(pitches: [root, root + 4, root + 7], start: t, length: 2 * beat, round: round))
            t += 2 * beat
            for (i, step) in pattern.steps.enumerated() {
                let length = (i == pattern.steps.count - 1 ? 2 : 1) * beat
                out.append(ScaleNote(pitches: [root + step], start: t, length: length, round: round))
                t += length
            }
        }
        return out
    }

    /// Seconds from the first chord to the end of the last note.
    public var duration: Double {
        notes.last.map { $0.start + $0.length } ?? 0
    }

    /// Every note the exercise plays, chords included.
    public var span: ClosedRange<Int> {
        let steps = pattern.steps + [0, 7]
        return (low + steps.min()!)...(high + steps.max()!)
    }

    static func clamp(_ note: Int) -> Int {
        min(max(note, rootRange.lowerBound), rootRange.upperBound)
    }
}

/// One thing the piano plays: a chord or a single note.
public struct ScaleNote: Equatable, Sendable {
    public let pitches: [Int]
    /// Start and length in seconds.
    public let start: Double
    public let length: Double
    /// Which round (index into `roots`) this belongs to.
    public let round: Int
}

public enum ScalePattern: String, Codable, Sendable, CaseIterable {
    case threeNote, fiveNote, fiveDown, triad, octaveArpeggio, octaveScale

    /// Semitones above the starting note, in the order they're sung. All major.
    public var steps: [Int] {
        switch self {
        case .threeNote: [0, 2, 4, 2, 0]
        case .fiveNote: [0, 2, 4, 5, 7, 5, 4, 2, 0]
        case .fiveDown: [7, 5, 4, 2, 0]
        case .triad: [0, 4, 7, 4, 0]
        case .octaveArpeggio: [0, 4, 7, 12, 7, 4, 0]
        case .octaveScale: [0, 2, 4, 5, 7, 9, 11, 12, 11, 9, 7, 5, 4, 2, 0]
        }
    }

    public var label: String {
        switch self {
        case .threeNote: "Three-note scale"
        case .fiveNote: "Five-note scale"
        case .fiveDown: "Five-note, coming down"
        case .triad: "Arpeggio"
        case .octaveArpeggio: "Octave arpeggio"
        case .octaveScale: "Octave scale"
        }
    }

    /// Scale degrees as a singer reads them: "1 2 3 2 1".
    public var degrees: String {
        let degree = [0: 1, 2: 2, 4: 3, 5: 4, 7: 5, 9: 6, 11: 7, 12: 8]
        return steps.map { String(degree[$0] ?? 0) }.joined(separator: " ")
    }
}

public enum ScaleDirection: String, Codable, Sendable, CaseIterable {
    case up, down, upAndDown

    public var label: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .upAndDown: "Up & back"
        }
    }
}

/// Words, not BPM: Sustain has no tempo numbers (Revision 5).
public enum ScaleSpeed: String, Codable, Sendable, CaseIterable {
    case slow, medium, fast

    /// Seconds per sung note.
    public var beat: Double {
        switch self {
        case .slow: 0.8
        case .medium: 0.55
        case .fast: 0.38
        }
    }

    public var label: String {
        switch self {
        case .slow: "Slow"
        case .medium: "Medium"
        case .fast: "Fast"
        }
    }
}

public enum Piano {
    static let names = ["C", "D♭", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    static let spoken = ["C", "D flat", "D", "E flat", "E", "F", "F sharp", "G", "A flat", "A", "B flat", "B"]

    /// 60 -> "C4", 63 -> "E♭4". Middle C is C4.
    public static func name(_ note: Int) -> String {
        names[note % 12] + String(note / 12 - 1)
    }

    /// For VoiceOver: "E flat 4".
    public static func spokenName(_ note: Int) -> String {
        spoken[note % 12] + " " + String(note / 12 - 1)
    }

    public static func isBlack(_ note: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(note % 12)
    }

    /// The keys to draw for some notes: whole octaves from C to C, at least two of them.
    public static func keyboard(for notes: ClosedRange<Int>) -> ClosedRange<Int> {
        let low = notes.lowerBound - notes.lowerBound % 12
        let top = notes.upperBound % 12 == 0 ? notes.upperBound : notes.upperBound + 12 - notes.upperBound % 12
        return low...max(top, low + 24)
    }
}
