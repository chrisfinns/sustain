import SwiftData
import SwiftUI
import SustainCore

/// The area chips + type-ahead shared by Capture and the practice card.
/// Up to 6 ranked chips (computed by the parent when it opens or the instrument changes, so they never jump),
/// a dashed "X · new" chip for a not-yet-saved area, and a suggestion list while typing.
struct AreaPicker: View {
    @Environment(\.theme) private var theme
    @Query private var areas: [Area]
    @Query private var instruments: [Instrument]
    @Query private var items: [Item]

    @Binding var text: String
    let selectedId: String?
    let pendingName: String?
    let chips: [String]
    var focus: FocusState<Bool>.Binding
    /// Pick or clear an existing area (nil clears).
    let onPick: (String?) -> Void
    /// "Make this a daily warm-up" chosen.
    let onWarmup: () -> Void
    /// A new area name chosen ("Create …").
    let onCreate: (String) -> Void
    /// Clear the dashed "new" chip.
    var onClearPending: () -> Void = {}

    @State private var highlight: Int?

    var body: some View {
        let snaps = areas.map(\.snap)
        let match = AreaMatching.match(text, areas: snaps)
        let byId = Dictionary(areas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                if let pendingName {
                    ChipButton(label: "\(pendingName) · new", dot: theme[.faint], on: true, dashed: true) { onClearPending() }
                }
                ForEach(chips, id: \.self) { id in
                    if let a = byId[id] {
                        ChipButton(label: a.name, dot: theme.color(a.color), on: a.id == selectedId) {
                            onPick(a.id == selectedId ? nil : a.id)
                        }
                    }
                }
                TextField("+ Type an area…", text: $text)
                    .textFieldStyle(.plain)
                    .font(Typo.small)
                    .focused(focus)
                    .padding(.horizontal, 12)
                    .frame(width: 180, height: 32)
                    .background(theme[.bg], in: Capsule())
                    .overlay(Capsule().stroke(theme[.line6], style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .onChange(of: text) { highlight = nil }
                    .onKeyPress(.downArrow) { move(1, count: match.rows.count) }
                    .onKeyPress(.upArrow) { move(-1, count: match.rows.count) }
                    .onKeyPress(phases: .down) { press in handleKey(press, match: match) }
                    .accessibilityLabel("Type an area")
            }

            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(match.rows.enumerated()), id: \.offset) { i, row in
                        let on = i == (highlight ?? match.defaultIndex)
                        Button { apply(row) } label: {
                            HStack(spacing: 10) {
                                Circle().fill(rowColor(row, byId)).frame(width: 8, height: 8)
                                Text(row.label).frame(maxWidth: .infinity, alignment: .leading)
                                Text(hint(row)).font(Typo.small).foregroundStyle(on ? theme[.muted] : theme[.faint])
                            }
                            .font(Typo.meta)
                            .padding(.horizontal, 10)
                            .frame(minHeight: 36)
                            .background(on ? theme[.sel2] : .clear, in: RoundedRectangle(cornerRadius: 7))
                            .overlay(alignment: .leading) {
                                if on { Rectangle().fill(theme[.accent]).frame(width: 3) }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                    if let problem = match.problem {
                        Text(problem.text).font(Typo.small).foregroundStyle(theme[.again]).padding(8)
                    }
                    Text("↑ ↓ to choose · Enter to pick · Esc to clear")
                        .font(.system(size: 11)).foregroundStyle(theme[.faint])
                        .padding(EdgeInsets(top: 4, leading: 10, bottom: 2, trailing: 10))
                }
                .padding(6)
                .background(theme[.bg], in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line4]))
            }
        }
    }

    private func move(_ step: Int, count: Int) -> KeyPress.Result {
        guard count > 0 else { return .ignored }
        let current = highlight ?? AreaMatching.match(text, areas: areas.map(\.snap)).defaultIndex
        if let current {
            highlight = (current + step + count) % count
        } else {
            highlight = step > 0 ? 0 : count - 1
        }
        return .handled
    }

    private func handleKey(_ press: KeyPress, match: AreaMatchResult) -> KeyPress.Result {
        let typed = !text.trimmingCharacters(in: .whitespaces).isEmpty
        switch press.key {
        case .return where typed && !press.modifiers.contains(.shift):
            if let i = highlight ?? match.defaultIndex, match.rows.indices.contains(i) { apply(match.rows[i]) }
            return .handled
        case .escape where typed:
            text = ""
            return .handled
        case .delete where !typed:
            if pendingName != nil { onClearPending() } else { onPick(nil) }
            return .ignored
        default:
            return .ignored
        }
    }

    private func apply(_ row: AreaMatchRow) {
        switch row {
        case .warmup: onWarmup()
        case let .area(id, _, _): onPick(id)
        case let .create(name): onCreate(name)
        }
        text = ""
        highlight = nil
    }

    private func rowColor(_ row: AreaMatchRow, _ byId: [String: Area]) -> Color {
        switch row {
        case .warmup: theme[.accent]
        case let .area(id, _, _): byId[id].map { theme.color($0.color) } ?? theme[.disabled]
        case .create: theme[.disabled]
        }
    }

    private func hint(_ row: AreaMatchRow) -> String {
        switch row {
        case .warmup: return "Practice setting"
        case .create: return "New area"
        case let .area(id, _, _):
            let refs = items.map { ItemAreaRef(id: $0.id, areaId: $0.area?.id, instrumentId: $0.instrument?.id ?? "other") }
            guard let top = AreaMatching.topInstrument(areaId: id, items: refs) else { return "Unused" }
            return instruments.first { $0.id == top }.map { "Mostly \($0.name)" } ?? ""
        }
    }

    /// The row Enter would pick for typed text: Capture commits it on save, so what you see is what gets saved.
    static func defaultRow(_ text: String, areas: [AreaSnap]) -> AreaMatchRow? {
        let m = AreaMatching.match(text, areas: areas)
        guard let i = m.defaultIndex, m.rows.indices.contains(i) else { return nil }
        return m.rows[i]
    }
}
