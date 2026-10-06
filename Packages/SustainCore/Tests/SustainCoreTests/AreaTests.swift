import Foundation
import Testing
@testable import SustainCore

@Suite struct NameKeyTests {
    @Test(arguments: [
        ("Warm-Up", "warm ups"), ("Techniques", "Technique"), ("B♭ voicings", "Bb voicings"),
        ("Ear  Training", "ear-training"), ("Range & Breath", "range breath"), ("SCALES", "scale"),
    ])
    func foldsTogether(a: String, b: String) {
        #expect(AreaNames.nameKey(a) == AreaNames.nameKey(b))
    }

    @Test func keepsMusicalSymbolsApart() {
        #expect(AreaNames.nameKey("C# major") != AreaNames.nameKey("C major"))
        #expect(AreaNames.nameKey("C♯ major") == AreaNames.nameKey("C# major"))
        #expect(AreaNames.nameKey("Bass") == "bass")
        #expect(AreaNames.nameKey("Gig set") == "gig set")
    }

    @Test func allowsEmoji() {
        #expect(!AreaNames.nameKey("🎸").isEmpty)
        #expect(AreaNames.validate("🎸 Riffs") == nil)
    }

    @Test func validation() {
        #expect(AreaNames.validate("") == .empty)
        #expect(AreaNames.validate("   ") == .empty)
        #expect(AreaNames.validate("!!! ...") == .noLetters)
        #expect(AreaNames.validate("No area") == .reserved)
        #expect(AreaNames.validate("All areas") == .reserved)
        #expect(AreaNames.validate("Slap") == nil)
        #expect(AreaNames.cleanName(String(repeating: "x", count: 40)).count == 32)
        #expect(AreaNames.cleanName("  Walking \n  Lines ") == "Walking Lines")
    }

    @Test func warmUpDetection() {
        #expect(AreaNames.isWarmupKey(AreaNames.nameKey("Warm-Up")))
        #expect(AreaNames.isWarmupKey(AreaNames.nameKey("daily warmups")))
        #expect(AreaNames.isWarmupKey("warmup"))
        #expect(!AreaNames.isWarmupKey(AreaNames.nameKey("Warmth")))
    }

    @Test func seedsAreTheNineteenAndCoverEverySuggestion() {
        let seeds = AreaNames.seedAreas(now: Date(timeIntervalSince1970: 0))
        #expect(seeds.count == 19)
        #expect(Set(seeds.map(\.nameKey)).count == 19)
        #expect(seeds.first?.id == "seed-repertoire")
        #expect(seeds.contains { $0.id == "seed-walking-line" && $0.name == "Walking Lines" })
        #expect(seeds.contains { $0.id == "seed-range-breath" })
        let keys = Set(seeds.compactMap(\.seedKey))
        for (inst, list) in AreaNames.seedSuggest {
            for k in list { #expect(keys.contains(k), "\(inst) suggests missing seed \(k)") }
        }
    }
}

@Suite struct AreaMatchingTests {
    let areas = AreaNames.seedAreas(now: Date(timeIntervalSince1970: 0))

    @Test func typoFindsTheAreaAndIsTheDefault() {
        let m = AreaMatching.match("Repertiore", areas: areas)
        #expect(m.rows.first == .area(id: "seed-repertoire", name: "Repertoire", tier: 3))
        #expect(m.defaultIndex == 0)
        #expect(m.rows.last == .create(name: "Repertiore"))
    }

    @Test func exactMatchHasNoCreateRow() {
        let m = AreaMatching.match("scales", areas: areas)
        #expect(m.rows == [.area(id: "seed-scale", name: "Scales", tier: 0)])
        #expect(m.defaultIndex == 0)
    }

    @Test func prefixMatchesComeAlphabetically() {
        let m = AreaMatching.match("Fi", areas: areas)
        #expect(m.rows.first == .area(id: "seed-fill", name: "Fills", tier: 1))
        #expect(m.defaultIndex == 0)
    }

    @Test func noMatchOffersCreate() {
        let m = AreaMatching.match("Slap", areas: areas)
        #expect(m.rows == [.create(name: "Slap")])
        #expect(m.defaultIndex == 0)
        #expect(m.rows[0].label == "Create \"Slap\"")
    }

    @Test func warmUpOffersTheSettingFirst() {
        let m = AreaMatching.match("warm up", areas: areas)
        #expect(m.rows.first == .warmup)
        #expect(m.defaultIndex == 0)
    }

    @Test func reservedNamesCantBeCreated() {
        let m = AreaMatching.match("No area", areas: areas)
        #expect(m.problem == .reserved)
        #expect(!m.rows.contains { if case .create = $0 { return true }; return false })
        #expect(AreaMatching.match("", areas: areas).rows.isEmpty)
    }

    @Test func osaCountsSwapsAsOne() {
        #expect(AreaMatching.osa("repertiore", "repertoire") == 1)
        #expect(AreaMatching.osa("abc", "abc") == 0)
        #expect(AreaMatching.osa("", "abc") == 3)
    }
}

@Suite struct AreaRankingTests {
    let areas = AreaNames.seedAreas(now: Date(timeIntervalSince1970: 0))

    @Test func dayOneUsesTheInstrumentSuggestions() {
        let ids = AreaRanking.rankForCapture(areas: areas, items: [], instrumentId: "drums", selectedId: nil)
        #expect(ids == ["seed-repertoire", "seed-rudiment", "seed-groove", "seed-fill", "seed-independence", "seed-technique"])
    }

    @Test func usageOnThisInstrumentComesFirst() {
        let items = [
            ItemAreaRef(id: "1", areaId: "seed-jam", instrumentId: "guitar"),
            ItemAreaRef(id: "2", areaId: "seed-jam", instrumentId: "guitar"),
            ItemAreaRef(id: "3", areaId: "seed-fretboard", instrumentId: "guitar"),
            ItemAreaRef(id: "4", areaId: "seed-groove", instrumentId: "bass"),
        ]
        let ids = AreaRanking.rankForCapture(areas: areas, items: items, instrumentId: "guitar", selectedId: nil)
        #expect(ids.count == 6)
        #expect(Array(ids.prefix(3)) == ["seed-jam", "seed-fretboard", "seed-repertoire"])
        #expect(!ids.contains("seed-groove"))
    }

    @Test func selectedAreaIsPinnedAndTheOrderIsStable() {
        let a = AreaRanking.rankForCapture(areas: areas, items: [], instrumentId: "guitar", selectedId: "seed-lyric")
        #expect(a.first == "seed-lyric")
        #expect(a.count == 6)
        let b = AreaRanking.rankForCapture(areas: areas, items: [], instrumentId: "guitar", selectedId: "seed-lyric")
        #expect(a == b)
        let c = AreaRanking.rankForCapture(areas: areas, items: [], instrumentId: "guitar", selectedId: "seed-chord")
        #expect(c == AreaRanking.rankForCapture(areas: areas, items: [], instrumentId: "guitar", selectedId: nil))
    }

    @Test func customInstrumentsGetGeneralSuggestionsAndNewCustomAreasShow() {
        var all = areas
        let slap = AreaNames.makeArea("Slap", areas: all, now: Date(timeIntervalSince1970: 100), id: "ar_slap")
        #expect(slap.isNew)
        all.append(slap.area)
        let ids = AreaRanking.rankForCapture(areas: all, items: [], instrumentId: "in_ukulele", selectedId: nil)
        #expect(ids == ["seed-repertoire", "seed-technique", "seed-ear-training", "seed-transcription", "seed-songwriting", "ar_slap"])
    }
}

@Suite struct AreaOpsTests {
    let t0 = Date(timeIntervalSince1970: 0)
    var areas: [AreaSnap] { AreaNames.seedAreas(now: t0) }

    @Test func makeAreaIsIdempotentAndUsesTheLeastUsedColor() {
        let first = AreaNames.makeArea("Slap", areas: areas, now: t0, id: "ar_1")
        #expect(first.isNew)
        let again = AreaNames.makeArea("slaps", areas: areas + [first.area], now: t0, id: "ar_2")
        #expect(!again.isNew)
        #expect(again.area.id == "ar_1")
        // 19 seeds over 8 colors: amber, coral, rose have 3; the rest have 2, so violet is next.
        #expect(first.area.color == .violet)
    }

    @Test func renameOntoAnExistingNameAsksToMerge() {
        let gig = AreaSnap(id: "ar_gig", name: "Gig set", color: .slate, createdAt: t0)
        let all = areas + [gig]
        #expect(AreaOps.rename("ar_gig", to: "scale", areas: all) == .askMerge(into: "seed-scale"))
        #expect(AreaOps.rename("ar_gig", to: "Gig set", areas: all) == .unchanged)
        #expect(AreaOps.rename("ar_gig", to: "No area", areas: all) == .problem(.reserved))
        #expect(AreaOps.rename("ar_gig", to: "Gig  sets", areas: all) == .renamed(name: "Gig sets", nameKey: "gig set"))
    }

    @Test func deleteThenUndoRestoresOnlyItemsStillWithoutAnArea() {
        let scale = areas.first { $0.id == "seed-scale" }!
        let before = [
            ItemAreaRef(id: "a", areaId: "seed-scale", instrumentId: "guitar"),
            ItemAreaRef(id: "b", areaId: "seed-scale", instrumentId: "bass"),
            ItemAreaRef(id: "c", areaId: "seed-lick", instrumentId: "guitar"),
        ]
        let u = AreaOps.delete(scale, items: before)
        #expect(u.itemIds == ["a", "b"])
        // Meanwhile "b" got a new area.
        let after = [
            ItemAreaRef(id: "a", areaId: nil, instrumentId: "guitar"),
            ItemAreaRef(id: "b", areaId: "seed-jam", instrumentId: "bass"),
            ItemAreaRef(id: "c", areaId: "seed-lick", instrumentId: "guitar"),
        ]
        let remaining = areas.filter { $0.id != "seed-scale" }
        #expect(AreaOps.undo(u, areas: remaining, items: after) == .restore(area: scale, itemIds: ["a"]))
    }

    @Test func mergeThenUndo() {
        let lick = areas.first { $0.id == "seed-lick" }!
        let items = [ItemAreaRef(id: "a", areaId: "seed-lick", instrumentId: "guitar")]
        let u = AreaOps.merge(lick, into: "seed-jam", items: items)
        let moved = [ItemAreaRef(id: "a", areaId: "seed-jam", instrumentId: "guitar")]
        let remaining = areas.filter { $0.id != "seed-lick" }
        #expect(AreaOps.undo(u, areas: remaining, items: moved) == .restore(area: lick, itemIds: ["a"]))
    }

    @Test func undoRefusesWhenTheNameIsTakenAgain() {
        let lick = areas.first { $0.id == "seed-lick" }!
        let u = AreaOps.delete(lick, items: [])
        let retaken = areas.filter { $0.id != "seed-lick" } + [AreaSnap(id: "ar_x", name: "Licks", color: .blue, createdAt: t0)]
        #expect(AreaOps.undo(u, areas: retaken, items: []) == .clash(name: "Licks"))
    }

    @Test func topInstrumentHint() {
        let items = [
            ItemAreaRef(id: "1", areaId: "seed-jam", instrumentId: "bass"),
            ItemAreaRef(id: "2", areaId: "seed-jam", instrumentId: "guitar"),
            ItemAreaRef(id: "3", areaId: "seed-jam", instrumentId: "guitar"),
        ]
        #expect(AreaMatching.topInstrument(areaId: "seed-jam", items: items) == "guitar")
        #expect(AreaMatching.topInstrument(areaId: "seed-fill", items: items) == nil)
    }
}
