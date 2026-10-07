import SwiftData
import SwiftUI
import SustainCore

/// Sensible defaults. Most people never touch these.
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Query(sort: \Instrument.order) private var instruments: [Instrument]
    @Query private var items: [Item]

    @State private var addingInstrument = false
    @State private var instrumentDraft = ""
    @State private var exporting = false
    @State private var exportDoc: BackupDocument?
    @FocusState private var instrumentFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Settings").font(Typo.pageTitle).tracking(-0.64)
                Text("Sensible defaults. Most people never touch these.").foregroundStyle(theme[.muted])
            }
            appearance
            scheduling
            instrumentsCard
            AreasSettings()
            yourData
            Text(versionLine)
                .font(Typo.mono(12))
                .foregroundStyle(theme[.faint])
                .textSelection(.enabled)
                .help("Note this with any bug, so you know which build it was")
        }
        .fileExporter(isPresented: $exporting, document: exportDoc, contentType: .json,
                      defaultFilename: BackupExport.fileName()) { result in
            switch result {
            case .success:
                app.settings.lastBackupAt = .now
                app.flash("Backup saved")
            case let .failure(error):
                app.flash("Couldn't save the backup: \(error.localizedDescription)")
            }
        }
    }

    /// "Sustain 0.3.0 (57)": the build number is the commit count from tools/install.sh, or 1 for a run from Xcode.
    private var versionLine: String {
        let info = Bundle.main.infoDictionary
        return "Sustain \(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
    }

    // MARK: - Cards

    private func section<C: View>(_ title: String, _ subtitle: String? = nil, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(Typo.sectionTitle)
                if let subtitle {
                    Text(subtitle).font(Typo.meta).foregroundStyle(theme[.muted]).fixedSize(horizontal: false, vertical: true)
                }
            }
            content()
        }
        .card(padding: 21)
    }

    private func settingRow<C: View>(_ label: String, _ desc: String, divider: Bool = true, @ViewBuilder control: () -> C) -> some View {
        VStack(spacing: 16) {
            if divider { Rectangle().fill(theme[.track]).frame(height: 1) }
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).fontWeight(.semibold)
                    Text(desc).font(Typo.meta).foregroundStyle(theme[.muted]).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                control()
            }
        }
    }

    private var appearance: some View {
        section("Appearance", "Paper & Ink. System follows your Mac's light or dark setting.") {
            PillSegment(options: ModeSetting.allCases.map { m in
                PillSegment<ModeSetting>.Option(id: m, label: m == .system ? "System" : m == .dark ? "Dark" : "Light")
            }, selected: app.settings.mode, tray: .bg) { app.settings.mode = $0 }
        }
    }

    private var scheduling: some View {
        let s = app.settings
        return section("Scheduling") {
            settingRow("Rating buttons", "Four buttons, like Anki, or the simple two-button flow. Same scheduler underneath.", divider: false) {
                PillSegment(options: [PillSegment<Bool>.Option(id: false, label: "Again · Hard · Good · Easy"),
                                      PillSegment<Bool>.Option(id: true, label: "Simple: Again · Good")],
                            selected: s.simple, tray: .bg) { s.simple = $0 }
            }
            settingRow("Desired retention", "How sure you want to be that you still have it. Higher means more reviews.") {
                Stepper2(value: "\(Int((s.retention * 100).rounded()))%", label: "retention",
                         dec: { s.retention = max(0.80, ((s.retention * 100).rounded() - 1) / 100) },
                         inc: { s.retention = min(0.97, ((s.retention * 100).rounded() + 1) / 100) })
            }
            settingRow("Longest gap", "Nothing goes longer than this without a check-in, so you never find out on stage.") {
                Stepper2(value: "\(s.maxInterval) days", label: "longest gap",
                         dec: { s.maxInterval = max(30, s.maxInterval - 10) },
                         inc: { s.maxInterval = min(120, s.maxInterval + 10) })
            }
            settingRow("New items per day", "Keeps Today from flooding when you capture a lot at once.") {
                Stepper2(value: "\(s.newPerDay)", label: "new items per day",
                         dec: { s.newPerDay = max(1, s.newPerDay - 1) },
                         inc: { s.newPerDay = min(10, s.newPerDay + 1) })
            }
        }
    }

    private var instrumentsCard: some View {
        section("Instruments") {
            FlowLayout(spacing: 8) {
                ForEach(instruments) { ins in
                    let n = items.filter { $0.instrument?.id == ins.id }.count
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(theme.color(ins.color)).frame(width: 9, height: 9)
                        Text(ins.name)
                        Text("\(n) \(n == 1 ? "item" : "items")").font(Typo.small).foregroundStyle(theme[.muted])
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(theme[.raised2], in: Capsule())
                    .overlay(Capsule().stroke(theme[.line3]))
                }
                if addingInstrument {
                    TextField("Instrument name, then Enter", text: $instrumentDraft)
                        .textFieldStyle(.plain)
                        .font(Typo.meta)
                        .focused($instrumentFocused)
                        .padding(.horizontal, 14)
                        .frame(width: 210, height: 36)
                        .background(theme[.bg], in: Capsule())
                        .overlay(Capsule().stroke(theme[.accent]))
                        .onSubmit {
                            app.addInstrument(instrumentDraft)
                            addingInstrument = false
                        }
                        .onExitCommand { addingInstrument = false }
                } else {
                    Button {
                        instrumentDraft = ""
                        addingInstrument = true
                        instrumentFocused = true
                    } label: {
                        Text("+ Add instrument").font(Typo.meta)
                            .padding(.horizontal, 14).frame(height: 36)
                            .foregroundStyle(theme[.muted])
                            .overlay(Capsule().stroke(theme[.line5], style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var yourData: some View {
        section("Your data", "Everything lives on this Mac, inside Sustain's own app container. No account, no server. That makes backups your job, so they're one click.") {
            HStack(spacing: 10) {
                Button("Export backup") {
                    do {
                        exportDoc = BackupDocument(data: try BackupExport.make(app.ctx, settings: app.settings))
                        exporting = true
                    } catch {
                        app.flash("Couldn't build the backup: \(error.localizedDescription)")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("Import backup") {}.buttonStyle(OutlineButtonStyle()).disabled(true).help("Arrives with the full backup format")
                Button("Import from Notion (CSV)") {}.buttonStyle(OutlineButtonStyle()).disabled(true).help("Arrives in a later update")
            }
            settingRow("Daily backup to a folder", "Pick a folder (Dropbox, iCloud Drive, a USB stick) and Sustain saves a copy there every day.") {
                LaterBadge()
            }
            settingRow("Sync with iCloud", "Keep your other Macs (and later an iPad) in step through your own iCloud account. Still no Sustain account or server.") {
                LaterBadge()
            }
            Text("Stored on this Mac · last backup \(app.settings.lastBackupAt.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "never") · export is JSON without media files for now")
                .font(Typo.mono(12))
                .foregroundStyle(theme[.muted])
        }
    }
}

private struct LaterBadge: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("Later")
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundStyle(theme[.muted])
            .background(theme[.sel2], in: Capsule())
    }
}

/// − value + control from the mockup's Scheduling card.
private struct Stepper2: View {
    @Environment(\.theme) private var theme
    let value: String
    let label: String
    let dec: () -> Void
    let inc: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            button("−", "Lower \(label)", dec)
            Text(value).font(Typo.mono(14)).frame(minWidth: 84)
            button("+", "Raise \(label)", inc)
        }
        .padding(4)
        .background(theme[.bg], in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line]))
    }

    private func button(_ text: String, _ a11y: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 16)).frame(width: 36, height: 36)
                .background(theme[.raised2], in: RoundedRectangle(cornerRadius: 7))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(a11y)
    }
}

/// Settings › Areas: the only place to manage them. Rename inline (onto an existing name asks to merge),
/// recolor with the swatch, delete with a 10-second Undo, add new ones.
private struct AreasSettings: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Query private var areas: [Area]
    @Query private var items: [Item]

    @State private var editing: String?
    @State private var editText = ""
    @State private var editError: String?
    @State private var mergeAsk: (src: String, dst: String)?
    @State private var newName = ""
    @State private var flashId: String?
    @FocusState private var editFocused: Bool

    var body: some View {
        let sorted = AreaNames.ordered(areas.map(\.snap))
        let byId = Dictionary(areas.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Areas").font(Typo.sectionTitle)
                Text("Optional labels for your items. Today doesn't use them, so rename, recolor or delete freely. Click a name to rename it. Renaming onto an existing area merges the two.")
                    .font(Typo.meta).foregroundStyle(theme[.muted])
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Two plain columns (not a lazy grid): about 20 rows, and every row exists for VoiceOver and UI tests.
            let half = (sorted.count + 1) / 2
            HStack(alignment: .top, spacing: 18) {
                ForEach([Array(sorted.prefix(half)), Array(sorted.dropFirst(half))], id: \.first?.id) { column in
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(column) { snap in
                            if let area = byId[snap.id] { row(area) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            HStack(spacing: 10) {
                TextField("+ Add area", text: $newName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(width: 260, height: 40)
                    .background(theme[.bg], in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line6], style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .onSubmit(add)
                    .accessibilityLabel("New area name")
                Button("Add", action: add).buttonStyle(OutlineButtonStyle(height: 40)).fontWeight(.semibold)
                let unlabeled = items.filter { $0.area == nil }.count
                Text("\(areas.count) \(areas.count == 1 ? "area" : "areas") · \(unlabeled) \(unlabeled == 1 ? "item" : "items") with no area")
                    .font(Typo.small).foregroundStyle(theme[.faint])
            }
            .padding(.top, 12)
            .overlay(alignment: .top) { Rectangle().fill(theme[.track]).frame(height: 1) }
        }
        .card(padding: 21)
    }

    private func row(_ area: Area) -> some View {
        let count = area.items?.count ?? 0
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Button { app.areaStore.cycleColor(area); app.save() } label: {
                    Circle().fill(theme.color(area.color)).frame(width: 12, height: 12)
                        .frame(width: 30, height: 30)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme[.line3]))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Change color")
                .accessibilityLabel("Change color of \(area.name)")

                if editing == area.id {
                    TextField("Area name", text: $editText)
                        .textFieldStyle(.plain)
                        .focused($editFocused)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .background(theme[.bg], in: RoundedRectangle(cornerRadius: 7))
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(theme[.accent]))
                        .onSubmit { commit(area) }
                        .onExitCommand { editing = nil; editError = nil }
                        .accessibilityLabel("Rename area")
                } else {
                    Button(area.name) {
                        editing = area.id
                        editText = area.name
                        editError = nil
                        mergeAsk = nil
                        editFocused = true
                    }
                    .buttonStyle(.plain)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help("Rename")
                    .accessibilityLabel("Rename \(area.name)")
                }

                Button(count == 0 ? "unused" : "\(count) \(count == 1 ? "item" : "items")") {
                    app.libraryArea = area.id
                    app.libraryStatus = .all
                    app.instrumentFilter = nil
                    app.screen = .library
                }
                .buttonStyle(.plain)
                .underline()
                .font(Typo.small)
                .foregroundStyle(theme[.muted])
                .help("Show in Library")

                Button { delete(area) } label: {
                    Image(systemName: "trash").frame(width: 32, height: 32).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme[.faint])
                .help("Delete")
                .accessibilityLabel("Delete \(area.name)")
            }
            .padding(.horizontal, 6)
            .frame(minHeight: 44)
            .background(flashId == area.id ? theme[.accentTint] : .clear, in: RoundedRectangle(cornerRadius: 8))

            if editing == area.id, let editError {
                Text(editError).font(Typo.small).foregroundStyle(theme[.again]).padding(EdgeInsets(top: 0, leading: 44, bottom: 6, trailing: 8))
            }
            if let ask = mergeAsk, ask.src == area.id, let dst = app.areaStore.area(id: ask.dst) {
                HStack(spacing: 8) {
                    Text("Merge \"\(area.name)\" into \"\(dst.name)\"? \(count) \(count == 1 ? "item moves." : "items move.")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Merge") { merge(area, into: dst) }.buttonStyle(PrimaryButtonStyle(height: 32))
                    Button("Cancel") { mergeAsk = nil }.buttonStyle(OutlineButtonStyle(height: 32, radius: 7))
                }
                .font(Typo.meta)
                .padding(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                .background(theme[.accentTint], in: RoundedRectangle(cornerRadius: 8))
                .padding(EdgeInsets(top: 0, leading: 40, bottom: 6, trailing: 0))
            }
        }
    }

    private func commit(_ area: Area) {
        switch app.areaStore.rename(area, to: editText) {
        case .unchanged:
            editing = nil
        case .renamed:
            editing = nil
            app.save()
            app.flash(AreaNames.isWarmupKey(area.nameKey)
                      ? "Renamed. To make items come first every day, set them to Warm-up."
                      : "Renamed to \"\(area.name)\"")
        case let .askMerge(dst):
            editing = nil
            mergeAsk = (area.id, dst)
        case let .problem(p):
            editError = p.text
        }
    }

    private func merge(_ src: Area, into dst: Area) {
        let name = src.name, dstName = dst.name
        let undo = app.areaStore.merge(src, into: dst)
        mergeAsk = nil
        app.save()
        app.flash("Merged \"\(name)\" into \"\(dstName)\" (\(undo.itemIds.count) \(undo.itemIds.count == 1 ? "item" : "items"))", undo: undo)
    }

    private func delete(_ area: Area) {
        let name = area.name
        let undo = app.areaStore.delete(area)
        if app.libraryArea == undo.area.id { app.libraryArea = "all" }
        editing = nil
        mergeAsk = nil
        app.save()
        let n = undo.itemIds.count
        app.flash("Deleted \"\(name)\"" + (n > 0 ? " · \(n) \(n == 1 ? "item now has" : "items now have") no area" : ""), undo: undo)
    }

    private func add() {
        let text = newName
        guard !AreaNames.cleanName(text).isEmpty else { return }
        switch app.areaStore.add(text, now: .now) {
        case let .added(area):
            newName = ""
            flashId = area.id
            app.save()
            app.flash(AreaNames.isWarmupKey(area.nameKey)
                      ? "Added. To make items come first every day, set them to Warm-up."
                      : "Added area \"\(area.name)\"")
        case let .existing(area):
            newName = ""
            flashId = area.id
            app.flash("Already there: \"\(area.name)\"")
        case let .problem(p):
            app.flash(p.text)
        }
    }
}
