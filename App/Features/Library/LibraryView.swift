import SwiftData
import SwiftUI
import SustainCore

/// Everything you've captured, on every instrument.
struct LibraryView: View {
    @Environment(\.theme) private var theme
    @Environment(AppModel.self) private var app
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @Query private var areas: [Area]
    @State private var search = ""
    @State private var confirmDelete: Item?

    var body: some View {
        let inInstrument = items.filter { app.instrumentFilter == nil || $0.instrument?.id == app.instrumentFilter }
        let inStatus = inInstrument.filter { matches($0, app.libraryStatus) }
        let rows = inStatus.filter(areaMatch).filter(searchMatch)
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Library").font(Typo.pageTitle).tracking(-0.64)
                    Text("Everything you've captured, on every instrument.").foregroundStyle(theme[.muted])
                }
                Spacer()
                Button { app.showCapture = true } label: { Label("Capture", systemImage: "plus") }
                    .buttonStyle(OutlineButtonStyle())
                    .fontWeight(.semibold)
            }

            HStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(theme[.muted])
                    TextField("Search songs, riffs, scales…", text: $search).textFieldStyle(.plain)
                        .accessibilityLabel("Search the library")
                }
                .padding(.horizontal, 14)
                .frame(minWidth: 240, maxWidth: .infinity, minHeight: 44)
                .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line2]))

                PillSegment(options: LibraryStatus.allCases.map { s in
                    PillSegment<LibraryStatus>.Option(id: s, label: s.label, count: "\(inInstrument.filter { matches($0, s) }.count)")
                }, selected: app.libraryStatus) { app.libraryStatus = $0 }

                areaMenu(inStatus)
            }

            VStack(spacing: 0) {
                HStack(spacing: 12) { columns("Name", "Instrument", "Area", "Status", "Next") }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme[.faint])
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(theme[.side])
                ForEach(rows) { item in
                    row(item)
                    Rectangle().fill(theme[.raised2]).frame(height: 1)
                }
                if rows.isEmpty {
                    Text("Nothing matches. Try another filter, or capture it.")
                        .foregroundStyle(theme[.muted])
                        .padding(EdgeInsets(top: 28, leading: 18, bottom: 28, trailing: 18))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme[.line]))
        }
        .confirmationDialog("Delete \"\(confirmDelete?.title ?? "")\"?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })) {
            Button("Delete item and its media", role: .destructive) {
                if let item = confirmDelete {
                    ItemStore(ctx: app.ctx, days: app.days).delete(item, media: app.media)
                    app.save()
                    app.flash("Deleted \"\(item.title)\"")
                }
                confirmDelete = nil
            }
        } message: {
            Text("Its reviews, notes and attachments are removed too. This can't be undone.")
        }
    }

    @ViewBuilder
    private func columns(_ a: String, _ b: String, _ c: String, _ d: String, _ e: String) -> some View {
        Text(a).frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
        Text(b).frame(width: 110, alignment: .leading)
        Text(c).frame(width: 150, alignment: .leading)
        Text(d).frame(width: 120, alignment: .leading)
        Text(e).frame(width: 130, alignment: .leading)
    }

    private func row(_ item: Item) -> some View {
        let status = statusChip(item)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Button(item.title) { app.open(item.id, items: items) }
                    .buttonStyle(.plain)
                    .fontWeight(.semibold)
                Text(item.artist.isEmpty ? " " : item.artist).font(Typo.small).foregroundStyle(theme[.faint])
            }
            .frame(minWidth: 240, maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(item.instrument.map { theme.color($0.color) } ?? theme[.disabled]).frame(width: 8, height: 8)
                Text(item.instrument?.name ?? "—").lineLimit(1)
            }
            .foregroundStyle(theme[.muted])
            .frame(width: 110, alignment: .leading)
            HStack(spacing: 8) {
                Circle().fill(item.area.map { theme.color($0.color) } ?? .clear).frame(width: 6, height: 6)
                Text(item.area?.name ?? "—").lineLimit(1)
            }
            .foregroundStyle(item.area == nil ? theme[.faint] : theme[.muted])
            .frame(width: 150, alignment: .leading)
            StatusChip(text: status.text, fg: status.fg, bg: status.bg).frame(width: 120, alignment: .leading)
            Text(nextText(item)).font(Typo.mono(12)).foregroundStyle(theme[.muted]).frame(width: 130, alignment: .leading)
        }
        .font(Typo.body)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .contextMenu {
            Button(item.paused ? "Resume" : "Pause") { item.paused.toggle(); app.save() }
            Button(item.reference ? "Practice again" : "Mark as reference") { item.reference.toggle(); app.save() }
            Divider()
            Button("Delete…", role: .destructive) { confirmDelete = item }
        }
    }

    private func areaMenu(_ inStatus: [Item]) -> some View {
        let sorted = AreaNames.ordered(areas.map(\.snap))
        let label = app.libraryArea == "all" ? "All" : app.libraryArea == "none" ? "No area" : (areas.first { $0.id == app.libraryArea }?.name ?? "All")
        return Menu {
            Button("All areas · \(inStatus.count)") { app.libraryArea = "all" }
            Button("No area · \(inStatus.filter { $0.area == nil }.count)") { app.libraryArea = "none" }
            Divider()
            ForEach(sorted) { a in
                Button("\(a.name) · \(inStatus.filter { $0.area?.id == a.id }.count)") { app.libraryArea = a.id }
            }
            Divider()
            Button("Manage areas…") { app.screen = .settings }
        } label: {
            HStack(spacing: 8) {
                Text("Area").foregroundStyle(theme[.faint])
                Text(label)
            }
            .font(Typo.meta)
        }
        .menuStyle(.borderlessButton)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(theme[.surf2], in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme[.line]))
        .fixedSize()
    }

    // MARK: - Rules from the mockup

    private func matches(_ item: Item, _ status: LibraryStatus) -> Bool {
        switch status {
        case .all: true
        case .paused: item.paused
        case .reference: item.reference && !item.paused
        case .active: !item.paused && !item.reference
        }
    }

    private func areaMatch(_ item: Item) -> Bool {
        switch app.libraryArea {
        case "all": true
        case "none": item.area == nil
        default: item.area?.id == app.libraryArea
        }
    }

    private func searchMatch(_ item: Item) -> Bool {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return true }
        let hay = [item.title, item.artist, item.area?.name ?? "", item.tags.joined(separator: " ")].joined(separator: " ").lowercased()
        return hay.contains(q)
    }

    private func statusChip(_ item: Item) -> (text: String, fg: Color, bg: Color) {
        if item.paused { return ("Paused", theme[.muted], theme[.track]) }
        if item.reference { return ("Reference", theme[.violet], theme[.violetTint]) }
        if item.card.isNew { return ("New", theme[.good], theme[.goodTint]) }
        if item.lane == .warmup { return ("Warm-up", theme[.easy], theme[.easyTint]) }
        switch Scheduler(settings: app.settings.scheduler, days: app.days).stage(of: item.card) {
        case .learning: return ("Learning", theme[.accent], theme[.accentTint2])
        case .mastered: return ("Mastered", theme[.easy], theme[.easyTint])
        default: return ("Review", theme[.text], theme[.sel2])
        }
    }

    private func nextText(_ item: Item) -> String {
        if item.paused || item.reference { return "—" }
        let ratedToday = !app.practice.todaysReviews(item, now: app.now).isEmpty
        if item.lane == .warmup && !ratedToday { return "Daily" }
        if item.card.isNew { return "Not started" }
        let days = app.days.daysBetween(app.now, item.due)
        if ratedToday { return "Done · \(Scheduler.nextLabel(days))" }
        if days < 0 { return "\(-days)d overdue" }
        if days == 0 { return "Today" }
        return Scheduler.nextLabel(days)
    }
}
