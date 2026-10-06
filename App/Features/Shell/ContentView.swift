import SwiftData
import SwiftUI
import SustainCore

enum Screen: String, CaseIterable, Identifiable {
    case today, library, notes, log, settings, practice

    var id: String { rawValue }

    static let sidebar: [Screen] = [.today, .library, .notes, .log, .settings]

    var title: String {
        switch self {
        case .today: "Today"
        case .library: "Library"
        case .notes: "Notes"
        case .log: "Log"
        case .settings: "Settings"
        case .practice: "Practice"
        }
    }

    var symbol: String {
        switch self {
        case .today: "calendar.badge.checkmark"
        case .library: "square.stack.3d.up"
        case .notes: "pencil.line"
        case .log: "chart.bar.xaxis"
        case .settings: "slider.horizontal.3"
        case .practice: "play.fill"
        }
    }
}

/// The window: sidebar on the left, the current screen on the right, Capture and the toast on top.
struct ContentView: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 232)
                .background(theme[.side])
                .overlay(alignment: .trailing) {
                    Rectangle().fill(theme[.sideLine]).frame(width: 1)
                }
            scrolling {
                Group {
                    switch app.screen {
                    case .today: TodayView().frame(maxWidth: 980, alignment: .leading)
                    case .practice: PracticeView()
                    case .library: LibraryView().frame(maxWidth: 1120, alignment: .leading)
                    case .settings: SettingsView().frame(maxWidth: 860, alignment: .leading)
                    case .notes: LaterScreen(title: "Notes", text: "General practice notes, lesson notes, gear and resources arrive in a later update.")
                    case .log: LaterScreen(title: "Practice log", text: "Every session is already saved. The log, heatmap and streak history arrive in the next update.")
                    }
                }
                .padding(EdgeInsets(top: 28, leading: 36, bottom: 40, trailing: 36))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme[.bg])
        }
        .overlay {
            if app.showCapture { CaptureView() }
        }
        .overlay(alignment: .bottomTrailing) {
            if let toast = app.toast {
                ToastView(toast: toast).padding(24).transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: app.toast)
    }

    @ViewBuilder
    private func scrolling<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        if isSnapshot {
            VStack(spacing: 0) { content(); Spacer(minLength: 0) }
        } else {
            ScrollView { content() }
        }
    }
}

private struct LaterScreen: View {
    @Environment(\.theme) private var theme
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(Typo.pageTitle).tracking(-0.64)
            Text(text).foregroundStyle(theme[.muted])
        }
    }
}

private struct Sidebar: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Query(sort: \Item.createdAt) private var items: [Item]
    @Query(sort: \Instrument.order) private var instruments: [Instrument]

    var body: some View {
        let counts = app.todayCounts(items)
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                WaveformMark()
                    .stroke(theme[.accent], style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 26)
                Text("Sustain").font(.system(size: 18, weight: .bold))
            }
            .padding(.horizontal, 8)

            Button { app.showCapture = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                    Text("Capture").fontWeight(.semibold)
                    Spacer()
                    KeyCap("⌘K", onAccent: true)
                }
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(theme[.onAccent])
                .background(theme[.accent], in: RoundedRectangle(cornerRadius: 10))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                ForEach(Screen.sidebar) { s in
                    let on = app.screen == s || (s == .today && app.screen == .practice)
                    Button { app.screen = s } label: {
                        HStack(spacing: 12) {
                            Image(systemName: s.symbol).frame(width: 18)
                            Text(s.title).fontWeight(.medium)
                            Spacer()
                            if s == .today { Text("\(counts.total)").font(Typo.mono(12)) }
                            if s == .library { Text("\(items.count)").font(Typo.mono(12)) }
                            if s == .settings { Text("⌘,").font(Typo.mono(11)).opacity(0.8) }
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(on ? theme[.text] : theme[.muted])
                        .background(on ? theme[.sel] : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("Instruments").padding(.horizontal, 12).padding(.bottom, 6)
                instrumentRow(id: nil, name: "All", color: theme[.disabled2], count: counts.total)
                ForEach(instruments) { ins in
                    instrumentRow(id: ins.id, name: ins.name, color: theme.color(ins.color), count: counts.byInstrument[ins.id] ?? 0)
                }
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 20, leading: 14, bottom: 20, trailing: 14))
        .font(Typo.body)
    }

    private func instrumentRow(id: String?, name: String, color: Color, count: Int) -> some View {
        let on = app.instrumentFilter == id
        return Button { app.instrumentFilter = id } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 9, height: 9)
                Text(name)
                Spacer()
                Text("\(count)").font(Typo.mono(12))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 36)
            .foregroundStyle(on ? theme[.text] : theme[.muted])
            .background(on ? theme[.raised2] : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The logo: the mockup's waveform path in a 24×24 box.
struct WaveformMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let raw: [(x: CGFloat, y: CGFloat)] = [(2, 12), (5, 12), (7, 6), (10, 18), (13, 9), (15, 14), (16.5, 12), (22, 12)]
        let pts = raw.map { CGPoint(x: rect.minX + $0.x * s, y: rect.minY + $0.y * s) }
        var p = Path()
        p.move(to: pts[0])
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }
}

/// A keyboard key hint, e.g. ⌘K or 1.
struct KeyCap: View {
    @Environment(\.theme) private var theme
    let text: String
    var onAccent = false

    init(_ text: String, onAccent: Bool = false) {
        self.text = text
        self.onAccent = onAccent
    }

    var body: some View {
        Text(text)
            .font(Typo.mono(11))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(onAccent ? theme[.onAccentLine] : theme[.line5]))
    }
}
