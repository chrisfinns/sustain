import SwiftUI
import SustainCore

/// Scales tab on Voice items: the piano gives the chord, plays the pattern to sing along with, then moves a half step.
/// Hold a key to hear one note. The exercise is a global preference, so it carries over between items.
struct ScalesPanel: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    let player: ScalePlayer

    var body: some View {
        let ex = app.settings.scales
        VStack(alignment: .leading, spacing: 12) {
            TimelineView(.animation(minimumInterval: 1 / 30, paused: !player.isPlaying)) { _ in
                let at = player.position
                let round = at.flatMap { p in player.notes.last { $0.start <= p }?.round }
                let sounding = at.map { p in player.notes.filter { $0.start <= p && p < $0.start + $0.length }.flatMap(\.pitches) } ?? []
                VStack(alignment: .leading, spacing: 14) {
                    header(ex, round: round)
                    PianoKeys(keys: Piano.keyboard(for: ex.span), lit: Set(sounding).union(player.held), marked: ex.low...ex.high, player: player)
                        .frame(height: 120)
                    if let problem = player.problem {
                        Text(problem).font(Typo.small).foregroundStyle(theme[.again])
                    } else if !player.hasPiano {
                        Text("The built-in piano sound didn't load, so you'll hear a plain tone.").font(Typo.small).foregroundStyle(theme[.faint])
                    }
                }
                .card(padding: 16)
            }
            controls(ex).card(padding: 14)
        }
    }

    private func header(_ ex: ScaleExercise, round: Int?) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                if let round, ex.roots.indices.contains(round) {
                    Text("Starting on \(Piano.name(ex.roots[round]))").font(Typo.sectionTitle)
                        .accessibilityLabel("Starting on \(Piano.spokenName(ex.roots[round]))")
                    Text("Round \(round + 1) of \(ex.roots.count)").font(Typo.mono(12)).foregroundStyle(theme[.muted])
                } else {
                    Text(ex.pattern.degrees).font(Typo.sectionTitle)
                    Text("\(Piano.name(ex.low)) to \(Piano.name(ex.high)) · \(ex.roots.count) \(ex.roots.count == 1 ? "round" : "rounds") · \(length(ex.duration))")
                        .font(Typo.small).foregroundStyle(theme[.muted])
                }
            }
            Spacer()
            KeyCap("Space").foregroundStyle(theme[.faint])
            Button { player.toggle(ex) } label: {
                Label(player.isPlaying ? "Stop" : "Play", systemImage: player.isPlaying ? "stop.fill" : "play.fill")
            }
            .buttonStyle(PrimaryButtonStyle(height: 36))
        }
    }

    private func controls(_ ex: ScaleExercise) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow {
                label("Pattern")
                Menu {
                    ForEach(ScalePattern.allCases, id: \.self) { p in
                        Button("\(p.label) · \(p.degrees)") { update { $0.pattern = p } }
                    }
                } label: {
                    Text("\(ex.pattern.label) · \(ex.pattern.degrees)").font(Typo.meta)
                }
                .menuStyle(.borderlessButton)
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme[.line]))
                .fixedSize()
            }
            GridRow {
                label("Starting notes")
                HStack(spacing: 8) {
                    noteStepper(ex.low, "Lowest starting note") { n in update { $0.setLow(n) } }
                    Text("to").font(Typo.small).foregroundStyle(theme[.muted])
                    noteStepper(ex.high, "Highest starting note") { n in update { $0.setHigh(n) } }
                }
            }
            GridRow {
                label("Direction")
                PillSegment(options: ScaleDirection.allCases.map { PillSegment<ScaleDirection>.Option(id: $0, label: $0.label) },
                            selected: ex.direction, height: 30) { d in update { $0.direction = d } }
                    .fixedSize()
            }
            GridRow {
                label("Speed")
                PillSegment(options: ScaleSpeed.allCases.map { PillSegment<ScaleSpeed>.Option(id: $0, label: $0.label) },
                            selected: ex.speed, height: 30) { s in update { $0.speed = s } }
                    .fixedSize()
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text).font(Typo.small).foregroundStyle(theme[.muted])
    }

    /// − C3 +, with the arrow-key adjust action for VoiceOver.
    private func noteStepper(_ note: Int, _ name: String, set: @escaping (Int) -> Void) -> some View {
        let range = ScaleExercise.rootRange
        return HStack(spacing: 0) {
            Button { set(note - 1) } label: {
                Image(systemName: "minus").frame(width: 28, height: 30).contentShape(Rectangle())
            }
            .disabled(note <= range.lowerBound)
            Text(Piano.name(note)).font(Typo.mono(13, weight: .semibold)).frame(minWidth: 40)
            Button { set(note + 1) } label: {
                Image(systemName: "plus").frame(width: 28, height: 30).contentShape(Rectangle())
            }
            .disabled(note >= range.upperBound)
        }
        .buttonStyle(.plain)
        .font(Typo.small)
        .foregroundStyle(theme[.text])
        .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme[.line4]))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(Piano.spokenName(note))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: set(note + 1)
            case .decrement: set(note - 1)
            @unknown default: break
            }
        }
    }

    /// Changing the exercise stops it, so what you hear always matches the controls.
    private func update(_ change: (inout ScaleExercise) -> Void) {
        player.stop()
        change(&app.settings.scales)
    }

    private func length(_ seconds: Double) -> String {
        seconds < 60 ? "\(Int(seconds.rounded())) s" : "about \(Int((seconds / 60).rounded())) min"
    }
}

/// A piano keyboard in paper and ink, the same in light and dark like a real one.
/// Lit keys are sounding; dotted keys are the starting notes. Hold a key to hear it.
struct PianoKeys: View {
    @Environment(\.theme) private var theme
    let keys: ClosedRange<Int>
    let lit: Set<Int>
    let marked: ClosedRange<Int>
    let player: ScalePlayer

    var body: some View {
        GeometryReader { geo in
            let whites = keys.filter { !Piano.isBlack($0) }
            let w = geo.size.width / CGFloat(max(1, whites.count))
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whites, id: \.self) { n in
                        key(n, black: false).frame(width: w, height: h)
                    }
                }
                // keys starts on a C, so every black key has its white neighbor to the left.
                ForEach(keys.filter { Piano.isBlack($0) }, id: \.self) { n in
                    let left = CGFloat(whites.firstIndex(of: n - 1) ?? 0)
                    key(n, black: true)
                        .frame(width: w * 0.6, height: h * 0.62)
                        .offset(x: (left + 1) * w - w * 0.3)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme[.paperLine]))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Piano")
    }

    private func key(_ n: Int, black: Bool) -> some View {
        let on = lit.contains(n)
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 4)
        return shape
            .fill(on ? theme[.accent] : black ? theme[.paperInk] : theme[.paper])
            .overlay(shape.stroke(theme[.paperLine], lineWidth: black ? 0 : 0.75))
            .overlay(alignment: .bottom) {
                VStack(spacing: 5) {
                    if marked.contains(n) && !on {
                        Circle().fill(theme[.accent]).frame(width: 6, height: 6)
                    }
                    if n % 12 == 0 {
                        Text(Piano.name(n)).font(.system(size: 9, weight: .medium))
                            .foregroundStyle(on ? theme[.onAccent] : theme[.paperMuted])
                    }
                }
                .padding(.bottom, 6)
            }
            .contentShape(shape)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { _ in player.press(n) }
                .onEnded { _ in player.release(n) })
            .accessibilityElement()
            .accessibilityLabel(Piano.spokenName(n))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                player.press(n)
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    player.release(n)
                }
            }
    }
}
