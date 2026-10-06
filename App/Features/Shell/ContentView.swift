import SwiftUI
import SustainCore

enum Screen: String, CaseIterable, Identifiable {
    case today, library, notes, log, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .library: "Library"
        case .notes: "Notes"
        case .log: "Log"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .today: "calendar.badge.checkmark"
        case .library: "square.stack.3d.up"
        case .notes: "pencil.line"
        case .log: "chart.bar.xaxis"
        case .settings: "slider.horizontal.3"
        }
    }
}

/// M0 step 2: the themed shell. Screens fill in over the next steps.
struct ContentView: View {
    @Environment(\.theme) private var theme
    @State private var screen: Screen = .today

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(screen: $screen)
                .frame(width: 232)
                .background(theme[.side])
                .overlay(alignment: .trailing) {
                    Rectangle().fill(theme[.sideLine]).frame(width: 1)
                }
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch screen {
                    case .today: TodayPlaceholder()
                    default:
                        Text(screen.title).font(Typo.pageTitle).tracking(-0.64)
                    }
                }
                .frame(maxWidth: 980, alignment: .leading)
                .padding(EdgeInsets(top: 28, leading: 36, bottom: 40, trailing: 36))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme[.bg])
        }
    }
}

private struct Sidebar: View {
    @Environment(\.theme) private var theme
    @Binding var screen: Screen

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                WaveformMark()
                    .stroke(theme[.accent], style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 26)
                Text("Sustain").font(.system(size: 18, weight: .bold))
            }
            .padding(.horizontal, 8)

            Button {} label: {
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
            }
            .buttonStyle(.plain)

            VStack(spacing: 2) {
                ForEach(Screen.allCases) { s in
                    Button { screen = s } label: {
                        HStack(spacing: 12) {
                            Image(systemName: s.symbol).frame(width: 18)
                            Text(s.title).fontWeight(.medium)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(screen == s ? theme[.text] : theme[.muted])
                        .background(screen == s ? theme[.sel] : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                SectionLabel("Instruments").padding(.horizontal, 12).padding(.bottom, 6)
                ForEach(seedInstruments) { inst in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3).fill(theme.color(inst.color)).frame(width: 9, height: 9)
                        Text(inst.name)
                        Spacer()
                        Text("0").font(Typo.mono(12))
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .foregroundStyle(theme[.muted])
                }
            }
            Spacer()
        }
        .padding(EdgeInsets(top: 20, leading: 14, bottom: 20, trailing: 14))
        .font(Typo.body)
    }

    private struct SidebarInstrument: Identifiable {
        let id: String
        let name: String
        let color: ColorName
    }

    private var seedInstruments: [SidebarInstrument] {
        [.init(id: "guitar", name: "Guitar", color: .amber), .init(id: "bass", name: "Bass", color: .violet),
         .init(id: "piano", name: "Piano", color: .blue), .init(id: "drums", name: "Drums", color: .coral),
         .init(id: "voice", name: "Voice", color: .teal)]
    }
}

private struct TodayPlaceholder: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(Typo.meta)
                .foregroundStyle(theme[.muted])
            Text("Today").font(Typo.pageTitle).tracking(-0.64)
        }
        VStack(alignment: .leading, spacing: 8) {
            Text("All caught up.").font(.system(size: 18, weight: .semibold))
            Text("Nothing else is due today. Capture something new, or come back tomorrow.")
                .foregroundStyle(theme[.muted])
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme[.surf], in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.line]))
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
