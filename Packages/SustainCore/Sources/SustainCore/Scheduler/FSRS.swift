import Foundation

/// FSRS-6, ported from ts-fsrs 5.4.2's long-term scheduler (`enable_short_term: false`, no fuzz).
/// Every intermediate value is rounded the way ts-fsrs rounds it, so results match its output.
/// `Tests/SustainCoreTests/Fixtures/fsrs-cases.json` holds the golden cases.
public struct FSRS: Sendable {
    public static let defaultWeights: [Double] = [
        0.212, 1.2931, 2.3065, 8.2956, 6.4133, 0.8334, 3.0194, 0.001, 1.8722, 0.1666, 0.796,
        1.4835, 0.0614, 0.2629, 1.6483, 0.6014, 1.8729, 0.5425, 0.0912, 0.0658, 0.1542,
    ]

    static let minStability = 0.001
    static let maxStability = 36_500.0
    static let dayMs = 86_400_000.0

    public let retention: Double
    public let maximumInterval: Int
    let w: [Double]
    let decay: Double
    let factor: Double
    let intervalModifier: Double

    public init(retention: Double, maximumInterval: Int, weights: [Double] = FSRS.defaultWeights) {
        precondition(weights.count == 21, "FSRS-6 needs 21 weights")
        precondition(retention > 0 && retention <= 1, "retention must be in (0, 1]")
        self.retention = retention
        self.maximumInterval = maximumInterval
        w = weights
        let d = -weights[20]
        let f = roundTo(exp((1 / d) * log(0.9)) - 1, 8)
        decay = d
        factor = f
        intervalModifier = roundTo((pow(retention, 1 / d) - 1) / f, 8)
    }

    /// The card after rating it at `now`. `days` decides how many calendar days have passed since the last review.
    public func next(_ card: FSRSCard, at now: Date, rating: Rating, days: LocalDays) -> FSRSCard {
        var current = card
        var elapsed = 0
        if card.state != .new, let last = card.lastReview {
            elapsed = days.daysBetween(last, now)
        }
        current.lastReview = now
        current.elapsedDays = elapsed
        current.reps += 1

        let g = rating.rawValue
        let memory: (d: Double, s: Double)
        var stabilities: [Double] = []
        if card.state == .new {
            current.scheduledDays = 0
            current.elapsedDays = 0
            for grade in 1...4 {
                stabilities.append(nextMemory(d: card.difficulty, s: card.stability, t: 0, g: grade, r: nil).s)
            }
            memory = nextMemory(d: card.difficulty, s: card.stability, t: 0, g: g, r: nil)
        } else {
            let r = forgettingCurve(Double(elapsed), card.stability)
            for grade in 1...4 {
                stabilities.append(nextMemory(d: card.difficulty, s: card.stability, t: elapsed, g: grade, r: r).s)
            }
            memory = nextMemory(d: card.difficulty, s: card.stability, t: elapsed, g: g, r: r)
            if rating == .again { current.lapses += 1 }
        }

        var again = nextInterval(stabilities[0])
        var hard = nextInterval(stabilities[1])
        var good = nextInterval(stabilities[2])
        var easy = nextInterval(stabilities[3])
        again = min(again, hard)
        hard = max(hard, again + 1)
        good = max(good, hard + 1)
        easy = max(easy, good + 1)
        let interval = [again, hard, good, easy][g - 1]

        current.difficulty = memory.d
        current.stability = memory.s
        current.scheduledDays = interval
        current.due = Date(timeIntervalSince1970: (now.timeIntervalSince1970 * 1000 + Double(interval) * Self.dayMs) / 1000)
        current.state = .review
        return current
    }

    // MARK: - Formulas (names follow ts-fsrs)

    func forgettingCurve(_ elapsedDays: Double, _ stability: Double) -> Double {
        roundTo(pow(1 + factor * elapsedDays / stability, decay), 8)
    }

    func initStability(_ g: Int) -> Double {
        max(w[g - 1], 0.1)
    }

    func initDifficulty(_ g: Int) -> Double {
        roundTo(w[4] - exp(Double(g - 1) * w[5]) + 1, 8)
    }

    func nextInterval(_ s: Double) -> Int {
        let ivl = min(max(1, jsRound(s * intervalModifier)), Double(maximumInterval))
        return Int(jsRound(ivl))
    }

    func linearDamping(_ deltaD: Double, _ oldD: Double) -> Double {
        roundTo(deltaD * (10 - oldD) / 9, 8)
    }

    func meanReversion(_ initial: Double, _ current: Double) -> Double {
        roundTo(w[7] * initial + (1 - w[7]) * current, 8)
    }

    func nextDifficulty(_ d: Double, _ g: Int) -> Double {
        let deltaD = -w[6] * Double(g - 3)
        let nextD = d + linearDamping(deltaD, d)
        return clamp(meanReversion(initDifficulty(4), nextD), 1, 10)
    }

    func nextRecallStability(_ d: Double, _ s: Double, _ r: Double, _ g: Int) -> Double {
        let hardPenalty = g == 2 ? w[15] : 1
        let easyBonus = g == 4 ? w[16] : 1
        let grow = exp(w[8]) * (11 - d) * pow(s, -w[9]) * (exp((1 - r) * w[10]) - 1) * hardPenalty * easyBonus
        return roundTo(clamp(s * (1 + grow), Self.minStability, Self.maxStability), 8)
    }

    func nextForgetStability(_ d: Double, _ s: Double, _ r: Double) -> Double {
        let value = w[11] * pow(d, -w[12]) * (pow(s + 1, w[13]) - 1) * exp((1 - r) * w[14])
        return roundTo(clamp(value, Self.minStability, Self.maxStability), 8)
    }

    func nextMemory(d: Double, s: Double, t: Int, g: Int, r: Double?) -> (d: Double, s: Double) {
        if d == 0 && s == 0 {
            return (clamp(initDifficulty(g), 1, 10), initStability(g))
        }
        let r = r ?? forgettingCurve(Double(t), s)
        let newS: Double
        if g == 1 {
            // Short-term off: w17/w18 don't apply, so the floor is the old stability.
            let afterFail = nextForgetStability(d, s, r)
            newS = clamp(roundTo(s, 8), Self.minStability, afterFail)
        } else {
            newS = nextRecallStability(d, s, r, g)
        }
        return (nextDifficulty(d, g), newS)
    }
}

/// JavaScript's Math.round: nearest integer, ties toward +infinity.
@inline(__always)
func jsRound(_ x: Double) -> Double {
    let f = x.rounded(.down)
    return x - f >= 0.5 ? f + 1 : f
}

@inline(__always)
func roundTo(_ x: Double, _ decimals: Int) -> Double {
    let f = pow(10.0, Double(decimals))
    return jsRound(x * f) / f
}

/// ts-fsrs clamp: min(max(value, lo), hi).
@inline(__always)
func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
    min(max(value, lo), hi)
}
