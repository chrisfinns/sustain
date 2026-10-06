import AppKit
import SwiftData
import SwiftUI
import SustainCore

/// The practice card: media on the left, notes on the right, four rating buttons below.
/// Keys: 1–4 rate (1–2 in Simple mode), Space play/pause, L loop, ←/→ previous/next item.
struct PracticeView: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Query(sort: \Item.createdAt) private var items: [Item]
    @Query private var areas: [Area]

    @State private var player = YouTubePlayerModel()
    @State private var tab: MediaTab = .video
    @State private var pickerOpen = false
    @State private var areaText = ""
    @State private var cardChips: [String] = []
    @FocusState private var areaFocused: Bool
    @FocusState private var notesFocused: Bool
    @FocusState private var cardFocused: Bool

    enum MediaTab: String, CaseIterable {
        case video = "Video", pdf = "Tab / PDF", images = "Images", takes = "Takes"
    }

    var body: some View {
        if let session = app.session, let item = items.first(where: { $0.id == session.currentId }) {
            card(item, session)
                .id(item.id)
                .onAppear { setUp(item) }
                .onChange(of: session.currentId) { if let next = items.first(where: { $0.id == session.currentId }) { setUp(next) } }
        } else {
            Text("Nothing to practice. Start a session from Today.")
                .foregroundStyle(theme[.muted])
        }
    }

    private func card(_ item: Item, _ session: SessionState) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            header(item, session)
            HStack(alignment: .top, spacing: 20) {
                media(item).frame(minWidth: 420, maxWidth: .infinity)
                aside(item).frame(minWidth: 280, idealWidth: 360, maxWidth: 420)
            }
            ratingBar(item)
            HStack {
                Text(app.settings.simple ? "Keys: 1 Again · 2 Good · Space play · L loop · ← → items" : "Keys: 1–4 rate · Space play · L loop · ← → items")
                Spacer()
                Button("Skip for now") { app.skip() }
                    .buttonStyle(.plain)
                    .underline()
                    .foregroundStyle(theme[.muted])
                    .font(Typo.meta)
            }
            .font(Typo.small)
            .foregroundStyle(theme[.faint])
        }
        .focusable()
        .focusEffectDisabled()
        .focused($cardFocused)
        .onKeyPress(phases: .down) { press in handleKey(press) }
    }

    // MARK: - Header

    private func header(_ item: Item, _ session: SessionState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                Button { app.screen = .today } label: {
                    Label("Today", systemImage: "chevron.left")
                }
                .buttonStyle(OutlineButtonStyle(height: 36, radius: 8, muted: true))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(item.title).font(Typo.practiceTitle).tracking(-0.4).lineLimit(2)
                        PillSegment(options: Lane.allCases.map { PillSegment<Lane>.Option(id: $0, label: $0.label, tip: $0.hint, accent: $0 != .normal) },
                                    selected: item.lane, height: 28) { lane in
                            ItemStore(ctx: app.ctx, days: app.days).setLane(item, lane, now: .now)
                            app.save()
                        }
                        .accessibilityLabel("Practice setting")
                    }
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(item.instrument.map { theme.color($0.color) } ?? theme[.disabled])
                            .frame(width: 8, height: 8)
                        Text(item.instrument?.name ?? "No instrument")
                        Text("·")
                        areaButton(item)
                        let rest = [item.artist, item.musicalKey.isEmpty ? "" : "Key \(item.musicalKey)"].filter { !$0.isEmpty }
                        if !rest.isEmpty { Text("· " + rest.joined(separator: " · ")) }
                    }
                    .font(Typo.meta)
                    .foregroundStyle(theme[.muted])
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    TimelineView(.periodic(from: session.startedAt, by: 1)) { ctx in
                        Label(formatClock(Int(ctx.date.timeIntervalSince(session.startedAt))), systemImage: "clock")
                            .font(Typo.mono(14))
                    }
                    if let pos = session.position {
                        Text("\(pos + 1) of \(session.queue.count)").font(Typo.mono(13)).foregroundStyle(theme[.muted])
                    }
                    Button("End session") { app.endSession() }
                        .buttonStyle(OutlineButtonStyle(height: 36, radius: 8))
                        .font(Typo.meta)
                }
            }

            GeometryReader { geo in
                let done = Double(session.rated.count) / Double(max(1, session.queue.count))
                ZStack(alignment: .leading) {
                    Capsule().fill(theme[.track])
                    Capsule().fill(theme[.accent]).frame(width: geo.size.width * min(1, done))
                }
            }
            .frame(height: 4)

            if pickerOpen { areaPanel(item) }
        }
    }

    private func areaButton(_ item: Item) -> some View {
        let area = item.area
        return Button { togglePicker(item) } label: {
            HStack(spacing: 6) {
                Circle().fill(area.map { theme.color($0.color) } ?? .clear).frame(width: 7, height: 7)
                Text(area?.name ?? "+ Area")
            }
            .padding(.horizontal, 9)
            .frame(minHeight: 26)
            .foregroundStyle(area == nil ? theme[.faint] : theme[.text])
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme[.line5], style: StrokeStyle(lineWidth: 1, dash: area == nil ? [4, 3] : [])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(area.map { "Area: \($0.name). Change area" } ?? "Add an area")
    }

    private func areaPanel(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Text("Area").fontWeight(.semibold).foregroundStyle(theme[.muted])
                    Text("· optional").foregroundStyle(theme[.faint])
                }
                .font(Typo.small)
                Spacer()
                Button("No area") { setArea(item, nil) }.buttonStyle(OutlineButtonStyle(height: 30, radius: 7, muted: true)).font(Typo.small)
                Button("Done") { pickerOpen = false }.buttonStyle(OutlineButtonStyle(height: 30, radius: 7)).font(Typo.small)
            }
            AreaPicker(text: $areaText, selectedId: item.area?.id, pendingName: nil, chips: cardChips, focus: $areaFocused,
                       onPick: { id in setArea(item, id) },
                       onWarmup: {
                           ItemStore(ctx: app.ctx, days: app.days).setLane(item, .warmup, now: .now)
                           app.save()
                       },
                       onCreate: { name in
                           let made = app.areaStore.ensure(name, now: .now)
                           item.area = made.area
                           app.save()
                           pickerOpen = false
                           if made.created { app.flash("New area \"\(made.area.name)\"") }
                       })
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: 680, alignment: .leading)
        .background(theme[.surf], in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.line3]))
        .onExitCommand { pickerOpen = false }
    }

    // MARK: - Media

    private func media(_ item: Item) -> some View {
        let atts = item.attachments ?? []
        let pdfs = atts.filter { $0.kind == .pdf }
        let images = atts.filter { $0.kind == .image }
        let takes = atts.filter { $0.kind == .audio }
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(MediaTab.allCases, id: \.self) { t in
                    let count: String = switch t {
                    case .video: item.youtubeId == nil ? "" : "1"
                    case .pdf: pdfs.isEmpty ? "" : "\(pdfs.count)"
                    case .images: images.isEmpty ? "" : "\(images.count)"
                    case .takes: takes.isEmpty ? "" : "\(takes.count)"
                    }
                    Button { tab = t } label: {
                        HStack(spacing: 8) {
                            Text(t.rawValue).fontWeight(.medium)
                            Text(count).font(Typo.mono(11)).foregroundStyle(theme[.faint])
                        }
                        .font(Typo.meta)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .foregroundStyle(tab == t ? theme[.text] : theme[.muted])
                        .background(tab == t ? theme[.sel] : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(tab == t ? theme[.line5] : theme[.line]))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(tab == t ? .isSelected : [])
                }
            }
            switch tab {
            case .video:
                if item.youtubeId != nil {
                    VideoPanel(item: item, player: player)
                } else {
                    AddVideoPanel(item: item)
                }
            case .pdf:
                AttachmentList(attachments: pdfs, emptyTitle: "No PDF yet",
                               emptyText: "Drop a tab, chart or sheet-music PDF in Capture. The built-in viewer arrives in the next update; for now it opens in Preview.")
            case .images:
                ImageGrid(attachments: images)
            case .takes:
                AttachmentList(attachments: takes, emptyTitle: "No takes yet",
                               emptyText: "Record one when it feels clean so you have something to compare against later. Recording arrives in a later update; dropped audio files show up here.")
            }
        }
    }

    // MARK: - Aside

    private func aside(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionLabel("Notes")
                    Spacer()
                    if notesFocused { Text("Saves as you type").font(Typo.small).foregroundStyle(theme[.faint]) }
                }
                TextEditor(text: Binding(get: { item.notes }, set: { item.notes = $0; item.updatedAt = .now }))
                    .font(Typo.body)
                    .lineSpacing(5)
                    .scrollContentBackground(.hidden)
                    .focused($notesFocused)
                    .padding(8)
                    .frame(minHeight: 190, idealHeight: 260, maxHeight: 420)
                    .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        if item.notes.isEmpty {
                            Text("Anything goes: what to watch for, timestamps, lyrics, chord shapes, what your teacher said…")
                                .font(Typo.body).foregroundStyle(theme[.faint])
                                .padding(EdgeInsets(top: 8, leading: 13, bottom: 0, trailing: 8))
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line2]))
                    .onChange(of: notesFocused) { if !notesFocused { app.save() } }
            }
            .card()

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("Progress")
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    GridRow {
                        stat("Last practiced", lastPracticed(item))
                        stat("Stage · reviews", "\(Scheduler(settings: app.settings.scheduler, days: app.days).stage(of: item.card).rawValue) · \(item.card.reps)")
                    }
                }
            }
            .card()
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Typo.small).foregroundStyle(theme[.faint])
            Text(value).font(Typo.meta)
        }
    }

    private func lastPracticed(_ item: Item) -> String {
        guard let last = item.lastReview else { return "Not yet" }
        let days = app.days.daysBetween(last, .now)
        let when = days == 0 ? "Today" : days == 1 ? "Yesterday" : last.formatted(.dateTime.month(.abbreviated).day())
        let latest = (item.reviews ?? []).max { $0.at < $1.at }
        return latest.map { "\(when) · \($0.rating.label)" } ?? when
    }

    // MARK: - Rating

    private func ratingBar(_ item: Item) -> some View {
        let base = app.practice.todaysReviews(item, now: .now).first?.prevCard ?? item.card
        let preview = Scheduler(settings: app.settings.scheduler, days: app.days).preview(base, at: .now)
        let shown = app.settings.ratings
        return HStack(spacing: 10) {
            ForEach(Array(shown.enumerated()), id: \.element) { i, r in
                Button { app.rate(r) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(r.label).font(.system(size: 17, weight: .bold)).foregroundStyle(theme.rating(r))
                            Spacer()
                            KeyCap("\(i + 1)").foregroundStyle(theme[.muted])
                        }
                        HStack(spacing: 4) {
                            Text(Scheduler.intervalLabel(preview[r] ?? 1)).font(Typo.mono(12)).foregroundStyle(theme[.text])
                            Text("· \(r.hint)").foregroundStyle(theme[.muted])
                        }
                        .font(Typo.small)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
                    .background(theme[.raised], in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.ratingLine(r)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(r.tip)
                .accessibilityLabel("\(r.label), next in \(Scheduler.intervalLabel(preview[r] ?? 1)). \(r.tip)")
            }
        }
        .padding(16)
        .background(theme[.surf], in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme[.line2]))
    }

    // MARK: - Behavior

    private func setUp(_ item: Item) {
        pickerOpen = false
        areaText = ""
        let atts = item.attachments ?? []
        tab = item.youtubeId != nil ? .video
            : atts.contains { $0.kind == .pdf } ? .pdf
            : atts.contains { $0.kind == .image } ? .images
            : atts.contains { $0.kind == .audio } ? .takes : .video
        if let id = item.youtubeId {
            player.load(videoId: id, start: Int(item.loopA ?? 0))
            player.loopA = item.loopA
            player.loopB = item.loopB
            player.loopOn = item.loopOn
            player.preferredRate = item.speed
        }
        cardFocused = true
    }

    private func togglePicker(_ item: Item) {
        if pickerOpen {
            pickerOpen = false
            return
        }
        let refs = items.map { ItemAreaRef(id: $0.id, areaId: $0.area?.id, instrumentId: $0.instrument?.id ?? "other") }
        cardChips = AreaRanking.rankForCapture(areas: areas.map(\.snap), items: refs,
                                               instrumentId: item.instrument?.id ?? "other", selectedId: item.area?.id)
        areaText = ""
        pickerOpen = true
        areaFocused = true
    }

    private func setArea(_ item: Item, _ id: String?) {
        item.area = app.areaStore.area(id: id)
        item.updatedAt = .now
        app.save()
        pickerOpen = false
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard !notesFocused, !areaFocused else { return .ignored }
        let shown = app.settings.ratings
        if let n = Int(press.characters), n >= 1, n <= shown.count {
            app.rate(shown[n - 1])
            return .handled
        }
        switch press.key {
        case .space:
            player.togglePlay()
            return .handled
        case .leftArrow:
            app.move(by: -1)
            return .handled
        case .rightArrow:
            app.move(by: 1)
            return .handled
        default:
            break
        }
        if press.characters.lowercased() == "l" {
            player.setLoop(a: player.loopA, b: player.loopB, on: !player.loopOn)
            return .handled
        }
        return .ignored
    }
}
