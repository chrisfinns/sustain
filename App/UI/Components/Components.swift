import SwiftUI
import SustainCore

// Shared pieces from the mockup. Sizes and colors follow design/mockup/Main.dc.html.

extension View {
    /// A `surf` card with a hairline border, radius 12.
    func card(padding: CGFloat = 16, radius: CGFloat = 12) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

private struct CardModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let padding: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme[.surf], in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(theme[.line]))
    }
}

/// Accent-filled button: Start session, Add, Save to log.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.horizontal, 18)
            .frame(minHeight: height)
            .foregroundStyle(theme[.onAccent])
            .background(theme[.accent], in: RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .contentShape(Rectangle())
    }
}

/// Outlined button: Capture in Library, Add & practice, End session.
struct OutlineButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    var height: CGFloat = 44
    var radius: CGFloat = 10
    var muted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, height < 40 ? 12 : 16)
            .frame(minHeight: height)
            .foregroundStyle(muted ? theme[.muted] : theme[.text])
            .background(configuration.isPressed ? theme[.raised] : .clear, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(theme[.line5]))
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
    }
}

/// A row of pill buttons in a tray: Time budget, Library status, Schedule, Appearance.
struct PillSegment<ID: Hashable>: View {
    @Environment(\.theme) private var theme
    struct Option: Identifiable {
        let id: ID
        let label: String
        var count: String? = nil
        var tip: String? = nil
        var accent = false
    }

    let options: [Option]
    let selected: ID
    var tray: Token = .surf2
    var height: CGFloat = 36
    let onSelect: (ID) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { opt in
                let on = opt.id == selected
                Button { onSelect(opt.id) } label: {
                    HStack(spacing: 6) {
                        Text(opt.label).fontWeight(.medium)
                        if let count = opt.count {
                            Text(count).font(Typo.mono(11)).foregroundStyle(theme[.faint])
                        }
                    }
                    .font(Typo.meta)
                    .padding(.horizontal, 12)
                    .frame(minHeight: height)
                    .foregroundStyle(on ? (opt.accent ? theme[.accent] : theme[.text]) : theme[.muted])
                    .background(on ? theme[.sel3] : .clear, in: RoundedRectangle(cornerRadius: 7))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(opt.tip ?? "")
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(theme[tray], in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line]))
    }
}

/// Instrument and area chips. `dashed` marks a not-yet-saved new area.
struct ChipButton: View {
    @Environment(\.theme) private var theme
    let label: String
    let dot: Color
    let on: Bool
    var dashed = false
    var square = false
    var height: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if square {
                    RoundedRectangle(cornerRadius: 2).fill(dot).frame(width: 8, height: 8)
                } else {
                    Circle().fill(dot).frame(width: 7, height: 7)
                }
                Text(label).fontWeight(.medium)
            }
            .font(Typo.small)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .foregroundStyle(on ? theme[.text] : theme[.muted])
            .background(on ? theme[.sel2] : .clear, in: Capsule())
            .overlay(
                Capsule().stroke(on ? (dashed ? theme[.faint] : dot) : theme[.line4],
                                 style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : []))
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A tinted capsule: "2d overdue", "New", "Learning".
struct StatusChip: View {
    let text: String
    let fg: Color
    let bg: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .foregroundStyle(fg)
            .background(bg, in: Capsule())
    }
}

/// Flowing layout for chips that wrap.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, line: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > width {
                y += line + lineSpacing
                x = 0
                line = 0
            }
            x += s.width + spacing
            line = max(line, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + line)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, line: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += line + lineSpacing
                x = bounds.minX
                line = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            line = max(line, s.height)
        }
    }
}

/// Bottom-right toast. Undo variant stays 10 s and pauses while hovered.
struct ToastView: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    let toast: AppModel.Toast

    var body: some View {
        HStack(spacing: 14) {
            Text(toast.text).frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.updatesFrequently)
            if toast.undo != nil {
                // The whole 32 pt pill is the button, not just the word.
                Button { app.undoAreaChange() } label: {
                    Text("Undo")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 32)
                        .foregroundStyle(theme[.text])
                        .background(theme[.bg], in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .keyboardShortcut("z", modifiers: .command)
                .accessibilityLabel("Undo")
            }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(theme[.bg])
        .padding(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12))
        .frame(maxWidth: 440)
        .background(theme[.text], in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: theme[.shadow], radius: 16, y: 12)
        .onHover { $0 ? app.holdToast() : app.resumeToast() }
        // Keep the Undo button its own element so VoiceOver (and UI tests) can reach it.
        .accessibilityElement(children: .contain)
    }
}

/// Dimmed overlay with a top-anchored panel, like the mockup's Capture and Session complete.
struct ModalOverlay<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.isSnapshot) private var isSnapshot
    var maxWidth: CGFloat = 620
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            theme[.overlay]
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            if isSnapshot {
                panel
            } else {
                ScrollView { panel }.scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    private var panel: some View {
        content()
            .padding(EdgeInsets(top: 22, leading: 24, bottom: 20, trailing: 24))
            .frame(maxWidth: maxWidth)
            .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme[.line3]))
            .shadow(color: theme[.shadow], radius: 32, y: 24)
            .padding(EdgeInsets(top: 64, leading: 16, bottom: 16, trailing: 16))
            .frame(maxWidth: .infinity)
    }
}
