import AppKit
import SwiftData
import SwiftUI
import SustainCore
import UniformTypeIdentifiers

/// Capture (⌘K): name it now, fill in the rest whenever.
/// Enter saves (or picks the highlighted area while typing one), ⇧Enter saves and keeps instrument, area and
/// schedule for the next one, Esc clears the area text and then closes.
struct CaptureView: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Query(sort: \Instrument.order) private var instruments: [Instrument]
    @Query private var areas: [Area]
    @Query(sort: \Item.createdAt) private var items: [Item]

    @State private var name = ""
    @State private var instrumentId = "guitar"
    @State private var areaId: String?
    @State private var pendingArea: String?
    @State private var areaText = ""
    @State private var chips: [String] = []
    @State private var lane: Lane = .normal
    @State private var notes = ""
    @State private var link = ""
    @State private var files: [URL] = []
    @State private var pasted: [Pasted] = []
    @State private var addingInstrument = false
    @State private var instrumentDraft = ""
    @State private var importing = false
    /// Enter can arrive through both onSubmit and onKeyPress; only the first one saves.
    @State private var lastSave = Date.distantPast
    @FocusState private var nameFocused: Bool
    @FocusState private var areaFocused: Bool
    @FocusState private var instrumentFocused: Bool

    struct Pasted: Identifiable {
        let id = UUID()
        let data: Data
        let ext: String
        let name: String
    }

    var body: some View {
        ModalOverlay(maxWidth: 620, onDismiss: close) {
            VStack(alignment: .leading, spacing: 18) {
                header
                field("Name") {
                    TextField("Song, riff, scale, exercise…", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused($nameFocused)
                        .onSubmit { save(practice: false, keep: NSEvent.modifierFlags.contains(.shift)) }
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(theme[.bg], in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line5]))
                        .accessibilityLabel("Name")
                }
                field("Instrument") { instrumentRow }
                field("Area", optional: true) {
                    AreaPicker(text: $areaText, selectedId: areaId, pendingName: pendingArea, chips: chips,
                               focus: $areaFocused,
                               onPick: { id in areaId = id; pendingArea = nil; if let id { chips = AreaRanking.pinFirst(chips, id) } },
                               onWarmup: { lane = .warmup },
                               onCreate: { n in pendingArea = n; areaId = nil },
                               onClearPending: { pendingArea = nil })
                }
                HStack(alignment: .bottom, spacing: 24) {
                    field("Schedule") {
                        PillSegment(options: Lane.allCases.map { PillSegment<Lane>.Option(id: $0, label: $0.label, tip: $0.hint, accent: $0 != .normal) },
                                    selected: lane, tray: .bg) { lane = $0 }
                    }
                    Text(lane.hint).font(Typo.small).foregroundStyle(theme[.faint]).padding(.bottom, 10)
                }
                field("Notes & media", optional: true) { notesBox }
                footer
            }
        }
        .onAppear(perform: setUp)
        .defaultFocus($nameFocused, true)
        .task {
            // Focus set during the first layout pass can be dropped; set it again once the overlay is up.
            try? await Task.sleep(for: .milliseconds(80))
            nameFocused = true
        }
        .onKeyPress(phases: .down) { press in handleKey(press) }
        .onExitCommand { if areaText.isEmpty { close() } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .image, .audio, .item], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result { files += urls }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Capture").font(Typo.modalTitle)
                Text("Name it now. Fill in the rest whenever.").font(Typo.meta).foregroundStyle(theme[.muted])
            }
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(theme[.muted])
                    .background(theme[.raised2], in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private func field<C: View>(_ label: String, optional: Bool = false, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(label).fontWeight(.semibold).foregroundStyle(theme[.muted])
                if optional { Text("· optional").foregroundStyle(theme[.faint]) }
            }
            .font(Typo.small)
            content()
        }
    }

    private var instrumentRow: some View {
        FlowLayout(spacing: 6) {
            ForEach(instruments) { ins in
                ChipButton(label: ins.name, dot: theme.color(ins.color), on: ins.id == instrumentId, square: true, height: 36) {
                    instrumentId = ins.id
                    chips = rank(instrumentId)
                }
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
                    .onSubmit(commitInstrument)
                    .onExitCommand { addingInstrument = false }
            } else {
                Button {
                    addingInstrument = true
                    instrumentDraft = ""
                    instrumentFocused = true
                } label: {
                    Text("+ Instrument").font(Typo.meta)
                        .padding(.horizontal, 14).frame(height: 36)
                        .foregroundStyle(theme[.muted])
                        .overlay(Capsule().stroke(theme[.line5], style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notesBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $notes)
                .font(Typo.body)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 110)
                .background(theme[.bg], in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Write anything. Drop PDFs, images or audio here, add as many as you like.")
                            .font(Typo.body).foregroundStyle(theme[.faint])
                            .padding(EdgeInsets(top: 8, leading: 13, bottom: 0, trailing: 8))
                            .allowsHitTesting(false)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme[.line3]))
            if !files.isEmpty || !pasted.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(files, id: \.self) { url in
                        thumbnail(name: url.lastPathComponent, image: NSImage(contentsOf: url),
                                  kind: MediaStore.kind(of: url)) { files.removeAll { $0 == url } }
                    }
                    ForEach(pasted) { p in
                        thumbnail(name: p.name, image: NSImage(data: p.data), kind: .image) { pasted.removeAll { $0.id == p.id } }
                    }
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "link").foregroundStyle(theme[.muted])
                TextField("Paste a YouTube link or any URL", text: $link)
                    .textFieldStyle(.plain)
                    .font(Typo.meta)
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(theme[.bg], in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme[.line3]))
                    .accessibilityLabel("Link")
                Button("+ Screenshot", action: pasteImage).buttonStyle(OutlineButtonStyle(height: 36, radius: 8)).font(Typo.small)
                    .help("Paste an image from the clipboard")
                Button("+ File") { importing = true }.buttonStyle(OutlineButtonStyle(height: 36, radius: 8)).font(Typo.small)
            }
            if let kind = LinkDetect.detect(link) {
                Label(detectText(kind), systemImage: "checkmark")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme[.easy])
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                    .background(theme[.easyTint], in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(12)
        .background(theme[.dim], in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.line5], style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        .dropDestination(for: URL.self) { urls, _ in
            files += urls.filter(\.isFileURL)
            return true
        }
    }

    private func thumbnail(name: String, image: NSImage?, kind: AttachmentKind, remove: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(theme[.raised])
                if let image {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Text(kind.rawValue.uppercased()).font(Typo.mono(11)).foregroundStyle(theme[.muted])
                }
            }
            .frame(width: 112, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(theme[.line3]))
            .overlay(alignment: .topTrailing) {
                Button(action: remove) {
                    Text("×").font(.system(size: 13)).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(theme[.overlay], in: Circle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .accessibilityLabel("Remove \(name)")
            }
            Text(name).font(.system(size: 11)).foregroundStyle(theme[.muted]).lineLimit(1).frame(width: 112, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Text(lane == .warmup ? "Shows up in Today under Warm-up ·" : "Shows up in Today under New ·")
                KeyCap("⇧↩")
                Text("adds another")
            }
            .font(Typo.small)
            .foregroundStyle(theme[.faint])
            Spacer()
            Button("Add & practice") { save(practice: true, keep: false) }
                .buttonStyle(OutlineButtonStyle())
                .fontWeight(.semibold)
                .disabled(trimmedName.isEmpty)
            Button { save(practice: false, keep: false) } label: {
                HStack(spacing: 10) { Text("Add"); KeyCap("↩", onAccent: true) }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(trimmedName.isEmpty)
        }
    }

    // MARK: - Behavior

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func setUp() {
        let known = Set(instruments.map(\.id))
        let preferred = [app.instrumentFilter, app.lastInstrumentId, "guitar"].compactMap { $0 }.first { known.contains($0) }
        instrumentId = preferred ?? instruments.first?.id ?? "guitar"
        chips = rank(instrumentId)
        nameFocused = true
    }

    private func rank(_ instrument: String) -> [String] {
        let refs = items.map { ItemAreaRef(id: $0.id, areaId: $0.area?.id, instrumentId: $0.instrument?.id ?? "other") }
        return AreaRanking.rankForCapture(areas: areas.map(\.snap), items: refs, instrumentId: instrument, selectedId: areaId)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard press.key == .return, !addingInstrument else { return .ignored }
        // The area box handles Enter itself while it has text.
        if areaFocused && !areaText.trimmingCharacters(in: .whitespaces).isEmpty && !press.modifiers.contains(.shift) { return .ignored }
        guard !trimmedName.isEmpty else { return .ignored }
        save(practice: false, keep: press.modifiers.contains(.shift))
        return .handled
    }

    private func save(practice: Bool, keep: Bool) {
        guard !trimmedName.isEmpty, Date.now.timeIntervalSince(lastSave) > 0.4 else { return }
        lastSave = .now
        // Text still typed in the area box is committed first, so what you see is what gets saved.
        if !areaText.trimmingCharacters(in: .whitespaces).isEmpty,
           let row = AreaPicker.defaultRow(areaText, areas: areas.map(\.snap)) {
            switch row {
            case .warmup: lane = .warmup
            case let .area(id, _, _): areaId = id; pendingArea = nil
            case let .create(n): pendingArea = n; areaId = nil
            }
            areaText = ""
        }
        var draft = ItemStore.Draft()
        draft.title = trimmedName
        draft.instrument = instruments.first { $0.id == instrumentId }
        draft.areaId = areaId
        draft.pendingArea = pendingArea
        draft.lane = lane
        draft.notes = notes
        draft.link = link
        draft.files = files
        draft.pasted = pasted.map { (data: $0.data, ext: $0.ext, name: $0.name) }
        let made = ItemStore(ctx: app.ctx, days: app.days).create(draft, media: app.media, now: .now)
        app.save()
        app.lastInstrumentId = instrumentId
        let areaNote = made.newArea.map { " · new area \"\($0.name)\"" } ?? ""
        let base = "Added \"\(made.item.title)\"\(areaNote)"
        if keep {
            areaId = made.item.area?.id
            pendingArea = nil
            name = ""
            notes = ""
            link = ""
            files = []
            pasted = []
            chips = rank(instrumentId)
            nameFocused = true
            app.flash(base + ". Next one?")
        } else if practice {
            app.showCapture = false
            app.open(made.item.id, items: items + [made.item])
        } else {
            app.showCapture = false
            app.flash(base + ". It shows up in Today under \(lane == .warmup ? "Warm-up" : "New").")
        }
    }

    private func close() {
        app.showCapture = false
    }

    private func commitInstrument() {
        if let id = app.addInstrument(instrumentDraft) {
            instrumentId = id
            chips = rank(id)
        }
        addingInstrument = false
    }

    private func pasteImage() {
        let pb = NSPasteboard.general
        if let data = pb.data(forType: .png) {
            pasted.append(Pasted(data: data, ext: "png", name: "Screenshot \(pasted.count + 1)"))
        } else if let tiff = pb.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff),
                  let png = rep.representation(using: .png, properties: [:]) {
            pasted.append(Pasted(data: png, ext: "png", name: "Screenshot \(pasted.count + 1)"))
        } else {
            app.flash("No image on the clipboard. Take a screenshot with ⇧⌘⌃4, then try again.")
        }
    }

    private func detectText(_ kind: LinkKind) -> String {
        switch kind {
        case .youtube: "YouTube video found. It embeds with A–B loop and speed control."
        case .pdf: "PDF found. It's saved as a link for now."
        case .link: "Link saved to this item."
        }
    }
}
