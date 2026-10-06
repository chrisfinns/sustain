import SwiftData
import SwiftUI
import SustainCore

/// Home screen: the list is already built. Warm-up, Focus, Due (most overdue first), New (capped), Done today.
struct TodayView: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Query(sort: \Item.createdAt) private var items: [Item]
    @State private var showDone = true

    var body: some View {
        let q = app.queue(items)
        let byId = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        VStack(alignment: .leading, spacing: 24) {
            header(q)

            if q.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("All caught up.").font(.system(size: 18, weight: .semibold))
                    Text("Nothing else is due today. Capture something new, or come back tomorrow.")
                        .foregroundStyle(theme[.muted])
                }
                .card(padding: 28)
            }

            section("Warm-up", q.warmup, byId, kind: .warmup, overdue: q.overdue)
            section("Focus", q.focus, byId, kind: .focus, overdue: q.overdue)
            section("Due · most overdue first", q.due, byId, kind: .due, overdue: q.overdue)
            if !q.fresh.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel("New · \(q.fresh.count + q.newStartedToday) of \(q.newPerDay) today")
                    ForEach(q.fresh) { qi in
                        if let item = byId[qi.id] { TodayRow(item: item, kind: .new, overdue: 0) { open(item) } }
                    }
                    if q.waiting > 0 {
                        Text("\(q.waiting) more new \(q.waiting == 1 ? "item waits" : "items wait") for tomorrow. Daily cap: \(q.newPerDay) (Settings).")
                            .font(Typo.meta)
                            .foregroundStyle(theme[.faint])
                            .padding(.horizontal, 4)
                    }
                }
            }

            if q.cut > 0 {
                Text("\(q.cut) more \(q.cut == 1 ? "item is" : "items are") due but over your \(app.budget.rawValue)-minute budget. They stay due and come first next time.")
                    .font(Typo.meta)
                    .foregroundStyle(theme[.muted])
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line4], style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }

            if !q.done.isEmpty { doneSection(q, byId) }
        }
    }

    private func open(_ item: Item) { app.open(item.id, items: items) }

    private func header(_ q: TodayQueue) -> some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(app.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(Typo.meta)
                    .foregroundStyle(theme[.muted])
                Text("Today").font(Typo.pageTitle).tracking(-0.64)
                let streak = app.practice.streak(now: app.now)
                if streak > 0 {
                    Label("\(streak)-day streak", systemImage: "flame")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .foregroundStyle(theme[.accent])
                        .background(theme[.accentTint], in: Capsule())
                }
            }
            Spacer()
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    Text("Time").font(Typo.small).foregroundStyle(theme[.muted]).padding(.leading, 10).padding(.trailing, 4)
                    PillSegment(options: TimeBudget.allCases.map { PillSegment<TimeBudget>.Option(id: $0, label: $0.label) },
                                selected: app.budget, tray: .surf2) { app.budget = $0 }
                }
                .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 10))
                Button {
                    app.startSession(items)
                } label: {
                    Label("Start session", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(q.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ list: [QueueItem], _ byId: [String: Item], kind: TodayRow.Kind, overdue: [String: Int]) -> some View {
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(title)
                ForEach(list) { qi in
                    if let item = byId[qi.id] {
                        TodayRow(item: item, kind: kind, overdue: overdue[qi.id] ?? 0) { open(item) }
                    }
                }
            }
        }
    }

    private func doneSection(_ q: TodayQueue, _ byId: [String: Item]) -> some View {
        let index = app.practice.todayIndex(now: app.now)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel("Done today · \(q.done.count)")
                Spacer()
                Button(showDone ? "Hide" : "Show") { showDone.toggle() }
                    .buttonStyle(.plain)
                    .font(Typo.small)
                    .underline()
                    .foregroundStyle(theme[.muted])
            }
            if showDone {
                ForEach(q.done) { qi in
                    if let item = byId[qi.id] {
                        DoneRow(item: item, rating: index[qi.id]?.last?.rating ?? .good) {
                            app.rerate(item, items: items)
                        }
                    }
                }
            }
        }
    }
}

/// One row in Today. Warm-ups show a ring and "Daily"; Focus a star and an accent border.
struct TodayRow: View {
    enum Kind { case warmup, focus, due, new }

    @Environment(\.theme) private var theme
    let item: Item
    let kind: Kind
    let overdue: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                marker.frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Typo.rowTitle).lineLimit(1)
                    ItemMetaLine(item: item)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                StatusChip(text: chip.text, fg: chip.fg, bg: chip.bg)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(kind == .focus ? theme[.accentLine] : theme[.line]))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(chip.text)")
    }

    @ViewBuilder private var marker: some View {
        switch kind {
        case .focus:
            Image(systemName: "star.fill").font(.system(size: 14)).foregroundStyle(theme[.accent])
        case .warmup:
            Circle().stroke(theme[.easy], lineWidth: 2).frame(width: 10, height: 10)
        case .new:
            Circle().fill(theme[.good]).frame(width: 10, height: 10)
        case .due:
            Circle().stroke(overdue > 0 ? theme[.again] : theme[.accent], lineWidth: 2).frame(width: 10, height: 10)
        }
    }

    private var chip: (text: String, fg: Color, bg: Color) {
        switch kind {
        case .warmup: ("Daily", theme[.muted], theme[.track])
        case .new: ("New", theme[.good], theme[.goodTint])
        case .due, .focus:
            overdue > 0 ? ("\(overdue)d overdue", theme[.again], theme[.againTint]) : ("Due today", theme[.accent], theme[.accentTint2])
        }
    }
}

struct DoneRow: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    let item: Item
    let rating: Rating
    let rerate: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.rating(rating)).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(theme[.muted]).lineLimit(1)
                Text(ItemMetaLine.text(item)).font(Typo.small).foregroundStyle(theme[.faint])
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(rating.label).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.rating(rating))
            Text("next \(Scheduler.nextLabel(app.days.daysBetween(app.now, item.due)))")
                .font(Typo.mono(12)).foregroundStyle(theme[.muted])
            Button("Re-rate", action: rerate)
                .buttonStyle(OutlineButtonStyle(height: 32, radius: 7, muted: true))
                .font(Typo.small)
        }
        .padding(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 12))
        .frame(minHeight: 48)
        .background(theme[.dim], in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line2], style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

/// "▪ Guitar · Repertoire · Jimi Hendrix". The area is left out when empty, so there's never a dangling "·".
struct ItemMetaLine: View {
    @Environment(\.theme) private var theme
    let item: Item

    static func text(_ item: Item) -> String {
        [item.instrument?.name ?? "", item.area?.name ?? "", item.artist].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(item.instrument.map { theme.color($0.color) } ?? theme[.disabled])
                .frame(width: 8, height: 8)
            Text(Self.text(item)).lineLimit(1)
        }
        .font(Typo.meta)
        .foregroundStyle(theme[.muted])
    }
}
