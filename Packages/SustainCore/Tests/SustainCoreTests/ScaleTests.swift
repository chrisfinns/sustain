import Foundation
import Testing
@testable import SustainCore

@Suite struct ScaleTests {
    @Test func walksUpThenBackDownByHalfSteps() {
        var ex = ScaleExercise(low: 48, high: 51)
        #expect(ex.roots == [48, 49, 50, 51, 50, 49, 48])
        ex.direction = .up
        #expect(ex.roots == [48, 49, 50, 51])
        ex.direction = .down
        #expect(ex.roots == [51, 50, 49, 48])
    }

    @Test func eachRoundIsChordThenPatternThenABreath() {
        let ex = ScaleExercise(pattern: .triad, low: 60, high: 61, direction: .up, speed: .slow)
        let b = ScaleSpeed.slow.beat
        let notes = ex.notes
        #expect(notes.count == 2 * (1 + 5))
        // Round 1: C major chord, then C E G E C, the last C held two beats.
        #expect(notes[0] == ScaleNote(pitches: [60, 64, 67], start: 0, length: 2 * b, round: 0))
        #expect(notes[1...5].map(\.pitches) == [[60], [64], [67], [64], [60]])
        #expect(notes[1].start == 2 * b)
        #expect(notes[5].length == 2 * b)
        // Round 2 starts a beat after round 1 ends, a half step up.
        let end1 = notes[5].start + notes[5].length
        #expect(notes[6] == ScaleNote(pitches: [61, 65, 68], start: end1 + b, length: 2 * b, round: 1))
        #expect(ex.duration == notes[11].start + notes[11].length)
        // Notes never overlap and always move forward.
        for (a, z) in zip(notes, notes.dropFirst()) { #expect(z.start >= a.start + a.length - 1e-9) }
    }

    @Test func rangeStaysInOrderAndOnThePiano() {
        var ex = ScaleExercise(low: 55, high: 50)
        #expect(ex.low...ex.high == 50...55)
        ex.setLow(58)
        #expect(ex.low...ex.high == 58...58)
        ex.setHigh(40)
        #expect(ex.low...ex.high == 40...40)
        ex.setLow(0)
        ex.setHigh(200)
        #expect(ex.low...ex.high == 36...72)
    }

    @Test func decodingClampsABadRange() throws {
        let json = #"{"pattern":"fiveNote","low":90,"high":10,"direction":"up","speed":"fast"}"#
        let ex = try JSONDecoder().decode(ScaleExercise.self, from: Data(json.utf8))
        #expect(ex.low...ex.high == 36...72)
        let back = try JSONDecoder().decode(ScaleExercise.self, from: JSONEncoder().encode(ex))
        #expect(back == ex)
    }

    @Test func patternsReadAsScaleDegrees() {
        #expect(ScalePattern.fiveNote.degrees == "1 2 3 4 5 4 3 2 1")
        #expect(ScalePattern.octaveArpeggio.degrees == "1 3 5 8 5 3 1")
        #expect(ScalePattern.fiveDown.degrees == "5 4 3 2 1")
        for p in ScalePattern.allCases { #expect(!p.degrees.contains("0"), "\(p) has a step outside the major scale") }
    }

    @Test func noteNamesAndKeyboard() {
        #expect(Piano.name(60) == "C4")
        #expect(Piano.name(63) == "E♭4")
        #expect(Piano.name(42) == "F♯2")
        #expect(Piano.spokenName(70) == "B flat 4")
        #expect(Piano.isBlack(61) && !Piano.isBlack(64))
        // The exercise's notes widen to whole octaves, at least two.
        #expect(Piano.keyboard(for: 50...67) == 48...72)
        #expect(Piano.keyboard(for: 48...72) == 48...72)
        #expect(Piano.keyboard(for: 36...84) == 36...84)
        let ex = ScaleExercise(pattern: .octaveArpeggio, low: 48, high: 55)
        #expect(ex.span == 48...67)
        #expect(ScaleExercise(pattern: .fiveDown, low: 48, high: 48).span == 48...55)
    }
}
