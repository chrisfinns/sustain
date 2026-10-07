# Sustain for Mac: Swift build plan

Status: decisions confirmed by Chris, Oct 6 2026. This is the build plan for the native macOS app.

What it builds on:
- **UI:** the approved mockup in `design/mockup/Main.dc.html` (canvas: https://claude.ai/artifact/TSe1AHctNW6q3tCF7dqDYC). Layout, copy, states, tokens and keys come from there. When this plan and the mockup disagree, this plan's "Changes from the mockup" section wins.
- **Product rules:** `docs/PLAN.md`: principles, Areas, Warm-up lanes, scheduler semantics and Visual design. They all still apply.
- **Logic:** `docs/reference/ts-domain/*.ts` plus the mockup's `computeQueue`, `matchRows`, `rankAreas`, `buildTheme`. Port the behavior and the tests, not the file layout.

This replaces the Delivery, Stack, Structure, Roadmap and Verification sections of `docs/PLAN.md`, which describe the old PWA.

## Status (Oct 6)
M0 is built on `main`. CI is green on both Linux (Core) and macOS 26 (the app).

- **Done:**
  - **SustainCore:** FSRS port matching ts-fsrs on 1,566 golden steps; Today queue, lanes, streak and heatmap; area rules; Paper & Ink theme matching the mockup's tokens, plus the contrast gate; link parsing; backup format v1.
  - **Store:** SwiftData SchemaV1, seeding, media files, area/item/practice stores.
  - **Screens:** shell and sidebar, Today, Capture, practice card (with the YouTube A–B loop and speed), Library, Settings with JSON export, and a Debug › YouTube Test window.
  - **Tests:** unit tests for the stores; UI tests for the plan's keyboard flows (Capture with only a name, type-to-create an area, Esc twice, ⇧Enter, rate with 3, delete an area and Undo).
  - **Screenshots:** every screen in dark and light, rendered with the mockup's sample data and pushed by CI to the `ci-screens` branch. Cloud sessions can `git fetch` them and compare against the mockup.
  - **Demo:** the "Sustain Demo" scheme (`-demo`) runs with that sample data in memory.
- **Bugs the UI tests caught and fixed:**
  - Capture opened without keyboard focus.
  - The toast hid its Undo button from VoiceOver, and only the word "Undo" was clickable.
  - Settings › Areas rows below the fold didn't exist for VoiceOver.
- **YouTube test (M0 step 1), run by Chris Oct 6 on macOS 26.6.2:** passed.
  - **Embed:** plays in the sandboxed app with no referrer errors.
  - **Speeds:** 50, 60, 75, 85 and 100 % all stick. `getAvailablePlaybackRates()` lists only 25 % steps, but YouTube accepts the in-between rates, so the practice card keeps the mockup's five speeds. Caveat: "got" is what `getPlaybackRate()` reports, not a measured playback speed.
  - **Loop:** natural wraps overshot B by 28 and 60 ms (target ≤ 100 ms). The reported worst of 1434 ms was a test artifact: turning Loop on after setting B, with the playhead already past B, counted the jump back to A as a wrap. Fixed in `player.html`: only playing across B counts.
  - **Hardening after the test:** the player's web view no longer has its timers throttled while Sustain is covered by another window (`inactiveSchedulingPolicy = .none`), so the loop should stay tight with a DAW in front. Not yet checked on the Mac.
- **Waiting on Chris:**
  1. Use the app daily for a week (Oct 7–14), logging friction in `docs/FRICTION.md`. Installed at `/Applications/Sustain.app` (Release build).
  2. Once, with a loop running, cover Sustain with another app's window and listen for late jumps back to A.

Small deviations made while building M0. Revisit if they feel wrong in use:
- **YouTube player:** uses `WKWebView`, the known-good path. SwiftUI's `WebView` can replace it later.
- **Shell:** a fixed 232 pt sidebar in an `HStack`, matching the mockup exactly, instead of `NavigationSplitView`.
- **Deleting an item:** asks for confirmation instead of offering an Undo toast. Area deletes do have Undo.
- **PDF and Takes tabs:** list the attached files and open them in Preview or Music until the built-in viewers land in M1. The Images tab is a real grid.
- **Notes:** the "Type / to insert…" hint is hidden until the `/` menu exists (M1).
- **Pasting screenshots in Capture:** done with a "+ Screenshot" button that reads the clipboard. ⌘V inside the text box pastes text only.

## Tech decisions

| Topic | Decision |
|---|---|
| Platform | macOS 26+ (Chris's Mac; nobody else runs it before M4), SwiftUI, Swift 6 language mode (strict concurrency), Xcode 26 |
| Project | XcodeGen `project.yml` (the `.xcodeproj` is generated and gitignored) + a local SwiftPM package `SustainCore` |
| Persistence | SwiftData with a `VersionedSchema` from day one. Store in the app's sandbox container (Application Support) |
| Media files | Real files in `Application Support/Sustain/Media/<attachmentId>.<ext>`, referenced by file name. Not blobs in the DB, so PDFKit, AVFoundation and Quick Look get URLs |
| Scheduler | Our own FSRS port inside `SustainCore` (~250 lines, no dependency), proven equal to ts-fsrs 5 by golden fixtures |
| YouTube | YouTube IFrame Player API (youtube-nocookie) in SwiftUI's `WebView`/`WebPage` (new in macOS 26), or `WKWebView` in a representable if the spike shows `WebPage` can't receive the page's messages. The A–B loop runs inside the page; Swift calls into it with JavaScript and receives `ready`/`state`/`time` messages |
| PDF / images / audio | PDFKit `PDFView`; `NSImage` grid + Quick Look; `AVAudioPlayer` / `AVAudioRecorder` |
| Zip (backups) | ZIPFoundation, the only third-party dependency (works on Linux too, so backup tests run in Core) |
| Tests | Swift Testing in `SustainCore` (runs on Linux and macOS); XCTest + XCUITest for the app |
| CI | GitHub Actions: Linux `swift test` for Core on every push; macOS build + tests + screen snapshots on PRs and on demand |
| Signing | v1 runs from Xcode or as a locally signed build. Developer ID + notarization in M4. The paid Apple Developer Program is only needed for notarized distribution and iCloud |
| Sandbox | On. Entitlements: network client (YouTube), user-selected files read/write (import/export, backup folder via security-scoped bookmark), audio input (takes, M3) |

## Working from cloud sessions (Linux)
Cloud containers run Linux: no Xcode, no SwiftUI, no SwiftData. That shapes the code:
- **Everything with rules lives in `SustainCore`**, Foundation-only, over plain value types. Cloud sessions build and test it with `swift test`.
- **The app target stays thin:** views, SwiftData models and the glue that applies Core's decisions to the store.
- **macOS CI is the compiler for the app.** Every push of app code gets a macOS build. The CI job also renders each screen (light + dark) to PNG with `ImageRenderer` and uploads them as artifacts, so screens can be checked against the mockup without a Mac.
- **Environment:** the cloud environment's setup script installs a Swift 6.2+ Linux toolchain (via `swiftly`). Without it, Core can't be tested here.
- macOS runner minutes cost 10× on private repos, so the macOS job runs on PRs and manual dispatch, not on every push.

## Repo layout
```
project.yml                       XcodeGen spec: app, unit-test and UI-test targets
Packages/SustainCore/             Foundation-only, builds on Linux
  Sources/SustainCore/
    Model/        Lane, Rating, ColorName, CardState, value snapshots (ItemSnap, AreaSnap, ReviewSnap)
    Dates/        LocalDay: dayKey, startOfDay, addDays, daysBetween, formatClock
    Scheduler/    FSRS.swift (engine), Scheduler.swift (rate, preview, rollback, cap, labels, stage)
    Today/        TodayQueue.swift (sections, new cap, budget), Streak.swift, Heatmap.swift
    Areas/        NameKey.swift, AreaRules.swift (validate, make, leastUsedColor),
                  AreaMatching.swift (matchAreas, osa), AreaRanking.swift (rankForCapture),
                  AreaOps.swift (rename/merge/delete/undo plans)
    Lanes/        LaneRules.swift (leaving warm-up → due tomorrow)
    Theme/        ThemeBases.swift, ThemeBuilder.swift (tokens as hex), Contrast.swift
    Media/        YouTubeURL.swift (id + start time), LinkDetect.swift
    Backup/       BackupDTO.swift (versioned Codable), BackupArchive.swift (zip)
    Import/       CSV.swift, NotionImport.swift (M3)
  Tests/SustainCoreTests/  + Fixtures/ (fsrs-cases.json, theme-paper.json)
App/
  SustainApp.swift, AppModel.swift (navigation, filters, toast, session state)
  Store/        Schema (SchemaV1 + migration plan), models, Seeder, MediaStore,
                ItemStore, AreaStore (the only area write path), ReviewStore, SessionStore
  UI/Theme/     Theme (tokens → Color), ThemeEnvironment, Typography
  UI/Components/  see "Components"
  Features/     Sidebar, Today, Practice (+ Media/), Capture, AreaPicker, Library,
                Settings, SessionSummary (M2), Log (M2), Notes (M3), NotionImport (M3)
  Resources/    player.html (YouTube), Assets.xcassets (app icon = the waveform mark)
AppTests/       store + services against an in-memory ModelContainer
AppUITests/     the end-to-end flows under "Verification"
tools/fsrs-fixtures/  Node script that generates FSRS golden cases with ts-fsrs (run once, output committed)
tools/theme-fixture/  Node script that runs the mockup's buildTheme and dumps the Paper & Ink tokens
.github/workflows/    core.yml (Linux), app.yml (macOS)
```

## Data model (SwiftData, SchemaV1)
CloudKit-safe from day one, so iCloud sync later is a switch and not a migration. That means every property has a default, relationships are optional, and there is no `@Attribute(.unique)`; uniqueness (area `nameKey`) is enforced by `AreaStore`.

- **Instrument**: `id`, `name` (≤24), `color: ColorName`, `order`, `createdAt`. Seeded: Guitar amber, Bass violet, Piano blue, Drums coral, Voice teal.
- **Area**: `id` (`seed-<slug>` or `ar_<ulid>`), `name` (1–32), `nameKey`, `color`, `seedKey?`, `createdAt`. Items relationship uses delete rule nullify.
- **Item**:
  - `id`, `title`, `instrument`, `area?`, `lane` (normal | focus | warmup), `warmupSince?`, `paused`, `reference`, `artist`, `key`, `source`, `tags: [String]` (import only)
  - `notes: String` (freeform, plain text in v1)
  - `youtube: YouTubeRef?` (url, videoId, loopA, loopB, loopOn, speed), `links: [String]`
  - FSRS card stored **flat** (`due`, `stability`, `difficulty`, `elapsedDays`, `scheduledDays`, `reps`, `lapses`, `state`, `lastReview`), so `due` can be sorted and filtered; a computed `card` maps to Core's `FSRSCard`
  - `createdAt`, `updatedAt`; `attachments` (cascade), `reviews` (cascade)
- **Attachment**: `id`, `kind` (image | pdf | audio | file), `name`, `mime`, `size`, `fileName`, `pdfLastPage?`, `isReferenceTake`, `createdAt`, `item?`
- **Review**: `id`, `item?`, `session?`, `rating`, `at`, `day` (local `YYYY-MM-DD`), `prevCard`, `nextCard` (Codable). This is the source for undo, re-rate, streak, heatmap and a future optimizer.
- **Session**: `id`, `startedAt`, `endedAt`, `durationSec`, `note`, `reviews`
- **Note** (M3): `id`, `title`, `tag`, `body`, `instrument?`, `updatedAt`
- **Meta**: key/value rows: `seededAreas`, `seededInstruments`, `schemaVersion`. Lives in the store, so a restored backup carries it and seeds are never re-added after delete.
- **Settings** (`UserDefaults`, included in backups): `retention` 0.80–0.97 (default 0.90), `maxInterval` 30–120 (60), `newPerDay` 1–10 (3), `simple` (false), `mode` system | dark | light, `autoBackupBookmark?`, `lastBackupAt?`.

## SustainCore: what gets ported

| Module | Port from | Behavior |
|---|---|---|
| `NameKey`, `AreaRules` | `areas.ts`, mockup `nameKey/cleanName` | NFKC, lowercase, ♯→#, ♭→b, punctuation folds to space, trailing plural "s" (not "ss", length ≥3). Reserved "no area"/"all area". Warm-up detection `\bwarm ?up\b` |
| `AreaMatching` | `matchAreas`, `osa` | Tiers exact → prefix → substring → typo (OSA ≤1, ≤2 for keys ≥8), max 6, warm-up row first, Create row when no exact match; default highlight rules |
| `AreaRanking` | `rankAreasForCapture`, `SEED_SUGGEST` | Max 6: used on this instrument → seed suggestions → unused custom areas; selected area pinned first |
| `AreaOps` | mockup `commitEdit/mergeArea/deleteArea/undoArea` | Returns patches + an `UndoRecord`; undo restores only items still where the change left them and refuses on a name clash |
| `FSRS`, `Scheduler` | `scheduler.ts` | Days only (`enable_short_term` off), no fuzz, retention and max interval from Settings, 60-day cap re-applied after the engine, `preview`, `intervalLabel` (1d / 3w / 2mo), `nextLabel`, `stageOf`, rollback |
| `TodayQueue` | mockup `computeQueue` + PLAN rules | Sections, new cap, budget, counts (below) |
| `LaneRules` | mockup `setLane` | Leaving warm-up after a review since `warmupSince` → due tomorrow; with no reviews it keeps its card |
| `Streak`, `Heatmap` | new | Streak = consecutive local days with ≥1 review, ending today or yesterday. Heatmap = 84 days, 4 levels by reviews per day (0, 1–3, 4–7, 8+) |
| `ThemeBuilder`, `Contrast` | mockup `themeBases/buildTheme/mix`, `checks/contrast.js` | Same math and rounding, so hexes match the mockup exactly |
| `YouTubeURL`, `LinkDetect` | `youtube.ts`, mockup `detect` | Every common URL shape, `t=`/`start=`; youtube / pdf / link detection |

**Today queue** (pure function of item snapshots, reviews today, `now` and settings):
- **Warm-up:** lane warmup, not paused or reference, not rated today. Sorted by `createdAt`, ignores due.
- **Focus:** lane focus, not new, due by end of today. Most overdue first.
- **Due:** lane normal, same rule.
- **New:** state New and lane ≠ warmup, oldest first. Cap = `newPerDay` minus new items already started today. The cap is global, and the instrument filter applies after it. A new Focus item shows under New (as in the mockup).
- **Budget:** keeps `round(minutes / 3)` items (15m → 5, 20m → 7, 30m → 10). The rest is reported as `cut`.
- **Also returns:** `waiting` (new items over the cap), `done` (rated today) and per-instrument counts for the sidebar.
- **Never reads areas.**

## Theme and components
- **Tokens:**
  - `Theme` holds every token `buildTheme` produces (`bg side dim surf surf2 surf3 raised raised2 track sel sel2 sel3 line…line6 sideLine text textSoft muted faint disabled disabled2 accent onAccent onAccentLine accentTint accentTint2 accentLine heat1 heat2 again/hard/good/easy (+Line, +Tint, againTint2) violet violetTint overlay shadow`, fixed `vid*` and `paper*`, plus the 8 data colors per mode).
  - Only **Paper & Ink** ships. The other three palettes stay in the mockup.
- **Parity:** a fixture dumped from the mockup's own `buildTheme` must equal Swift's output for paper/dark and paper/light. The contrast gate from `contrast.js` runs as a Core test.
- **Mode:**
  - `@Environment(\.colorScheme)` picks dark or light tokens.
  - Settings › Appearance sets `.preferredColorScheme` (System = nil) on the window.
  - The theme is injected as an environment value.
- **Type** (from the mockup's sizes):

  | Use | Spec |
  |---|---|
  | Page title | 32 bold, −0.02em |
  | Practice title | 26 bold |
  | Modal title | 20 bold |
  | Settings section | 17 bold |
  | Row title | 15 semibold |
  | Body | 14 |
  | Meta | 13 |
  | Small | 12 |
  | Section label | 11 semibold, uppercase, 0.12em tracking, `faint` |
  | Numbers | mono 11–14; 24 for stats |

- **Shape and spacing:**
  - Radius: 10 for rows and buttons, 12 for cards, 14 for the rating panel, 16 for modals, capsules for pills.
  - Height: 44 for primary hit targets, 36 for secondary, 32 for small.
  - Main pane padding: 28 / 36 / 40.
- **Components** (each used on 2+ screens):
  - `SectionLabel`, `PillSegment` (budgets, statuses, lanes, speeds, mode), `ColorDot`, `ChipButton` (instrument and area chips, dashed "new" variant)
  - `StatusChip`, `KeyCap`, `PrimaryButton`, `OutlineButton`, `Card`
  - `ItemRow` (ring / star / check variants), `Toast` (2.8 s; 10 s with Undo, paused on hover or focus), `ModalOverlay` (dim overlay + `surf2` panel at top, like the mockup), `Stepper`
  - `AreaPicker` (chips + type-ahead + suggestion list, shared by Capture and the practice card), `HeatmapGrid`, `MixBar`
- **Accessibility:**
  - Every `aria-label` in the mockup becomes an `accessibilityLabel`.
  - `aria-pressed` becomes the `.isSelected` trait.
  - The suggestion list announces the highlighted row.
  - Respect Reduce Motion.

## Screen map (mockup → SwiftUI)

**Shell:** one `WindowGroup`, default 1440×900, minimum 1024×700.
- A `NavigationSplitView` with a custom-styled sidebar (`side` background):
  - the waveform logo + "Sustain"
  - the Capture button with a ⌘K cap
  - Today (queue count), Library (item count), Notes, Log, Settings (⌘,)
  - "Instruments": All + each instrument with its Today count, acting as a filter
- Settings is a sidebar screen, as in the mockup, not a separate window: the app's ⌘, command routes there.
- Menus:
  - File: Capture ⌘K, Export Backup…, Import Backup…
  - View: Today ⌘1, Library ⌘2, Notes ⌘3, Log ⌘4
  - Practice: Play/Pause, Loop, Next, Previous

| Screen | SwiftUI shape | Must match / behave |
|---|---|---|
| **Today** | `ScrollView` max width 980 | Date line, "Today", streak chip. Time pills 15m/20m/30m/All, Start session (disabled when empty). Sections Warm-up ("Daily" chip, ring dot), Focus (star, accent border), "Due · most overdue first" ("Nd overdue" / "Due today"), "New · x of N today" plus waiting line. Budget cut note. "Done today · N" with Hide/Show, rated-color check, "next in 12d", Re-rate. Empty state "All caught up." Meta line = instrument · area (only if set) · artist |
| **Practice card** | Header + `HStack` media (3) / aside (2), stacking under ~900 pt wide; rating panel below | ← Today; title; Regular/Focus/Warm-up segment with the mockup's tooltips; instrument · area button ("+ Area" dashed) · artist · Key; elapsed timer (`TimelineView`), "3 of 12", End session; progress bar; inline area picker (No area / Done). Tabs Video, Tab / PDF, Images, Takes with counts; default = first tab with content; empty states with the mockup copy. Notes card (autosave after 0.5 s, "Saved"), Progress card (Last practiced, Stage · reviews). Rating buttons: label, key cap, interval preview, hint, tooltip; Simple mode shows Again/Good as 1/2. Key hint line + "Skip for now" |
| **Capture** | `ModalOverlay`, panel max width 620, name field focused on open | Name; Instrument chips + "+ Instrument" inline field; Area · optional (`AreaPicker`); Schedule segment + hint text; "Notes & media" box: text, ⌘V paste of images, drop of files, thumbnails with ×, link field with detection banner, "+ Screenshot" / "+ File" (file importer); footer hint with ⇧↩; Add & practice / Add ↩. Keys: Enter commits the highlighted area row when the area box has text, otherwise saves; ⇧Enter saves and keeps instrument, area and lane; Esc clears the area text, then closes; ↑/↓ moves through rows; Backspace in an empty area box clears the area. A new area is created only together with the item |
| **Library** | Custom grid (not `Table`, to match the mockup), min width 720 | Search (title, artist, area, tags); status pills Active/Paused/Reference/All with counts; Area menu (All, No area, areas with counts, "Manage areas…"); columns Name (+ artist), Instrument, Area (dot, "—"), Status chip, Next. Empty text. Click a name to open the practice card. Sidebar instrument filter applies |
| **Settings** | `ScrollView` of `Card`s, max width 860 | **Appearance:** System (dark) / Dark / Light. **Scheduling:** 4 buttons vs Simple; steppers for retention (80–97 %), longest gap (30–120 days, step 10), new per day (1–10). **Instruments:** chips with counts + "+ Add instrument". **Areas:** two-column rows: swatch cycles the 8 colors, click name to rename inline, rename onto an existing name asks inline to merge, "N items" links to the Library filter, trash deletes with a 10 s Undo toast (also ⌘Z); "+ Add area" + count line. **Your data:** Export backup, Import backup, Import from Notion (CSV), Daily backup to a folder (toggle → folder picker), Sync with iCloud (disabled, "Later"), "Stored on this Mac · last backup …" |
| **Session complete** (M2) | `ModalOverlay` max width 580 | Time, Reviewed, Streak; rating mix bar + legend; 12-week heatmap; Session note; Back to Today / Save to log |
| **Log** (M2) | max width 1000 | Stat tiles (last 5 sessions time, items reviewed, streak, library size); 12-week heatmap with Less/More legend; session rows (date, min · items, mix bar, note) |
| **Notes** (M3) | list (1) + editor (3) | Note list (title, tag · edited); editor with Insert row (Checklist, Image, PDF, YouTube, Recording, Link to item), title, body, embed cards |
| **Notion import** (M3) | `ModalOverlay` max width 600 | Instrument for this file; "Notion Area → Becomes" table (Exact match / Same name / Warm-up setting / New area) + summary line; Cancel / Import |

**Practice keys:**
- Handled with `.onKeyPress` on the practice view, and ignored while a text field has focus.
- 1–4 rate (1–2 in Simple mode), Space play/pause, L toggles the loop, ←/→ previous or next item, Esc closes the area picker.

**Day rollover:** Today rebuilds on `NSCalendarDayChanged`, on wake from sleep and when the app becomes active.

## Media
- **YouTube** (`Resources/player.html` in the web view the spike picks):
  - **Loop:** inside the page, a 50 ms timer seeks to A whenever the playhead passes B. Loop points are draggable handles on the bar, plus "Set A here" / "Set B here".
  - **Speed:** pills 50/60/75/85/100 %.
  - **Saving:** loop points, loop state and speed save per item.
  - **Bridge:** the page posts `ready`, `state` and `time` messages to Swift.
  - **Offline:** shows a "Video needs an internet connection" state.
  - **Privacy:** this is the only network use in the app.
- **PDF:**
  - `PDFView` in single-page mode, with ‹ › and "Page x of n"; it reopens on `pdfLastPage`.
  - The page renders as-is (the mockup's fixed paper color).
- **Images:** an adaptive grid (min 200 pt) at 4:3; click opens Quick Look. ⌘V pastes a screenshot and dropping files works on the whole media pane.
- **Takes:**
  - Rows with play button, label, "Reference" chip, date · length. Dropped audio lands here.
  - Recording with `AVAudioRecorder` (m4a) arrives in M3, together with the microphone permission prompt.
- **Notes `/` insert (M1):**
  - Typing `/` at the start of a line opens an insert menu (Image, PDF, YouTube link, Recording).
  - The chosen media attaches to the item and lands in its tab, and a plain reference line is inserted into the notes.
  - Rich inline embeds (images inside the text) come later with an `NSTextView` wrapper and text attachments. macOS 26's rich-text `TextEditor` handles formatting, not embedded files.
- **MediaStore:**
  - Copies files in, then writes the Attachment row.
  - Removes the file when its attachment is deleted.
  - On launch, deletes orphaned files older than a day.

## Backup
- **M0, JSON export:** `BackupDTO` v1 (instruments, areas, items, reviews, sessions, meta, settings), written to a file the user picks.
- **M3, `.sustain` archive:** a zip of `data.json` + `media/`.
  - **Import:** shows counts first, then replaces the store. It runs `repairReferences` (dangling or duplicate areas) and reports what it fixed.
  - **Daily auto-backup:** saves to the bookmarked folder at launch and every 24 h while open, keeps the last 14 and updates "last backup".

## Changes from the mockup (gaps the mockup leaves open)
1. **Appearance:** only System / Dark / Light. The four palette cards go away because only Paper & Ink ships.
2. **Fonts:** SF Pro + SF Mono, the same fonts the mockup renders (Main sets `-apple-system` / `SF Mono`). Nothing to bundle.
3. **Editing an item:** the mockup has no way to rename, pause, mark as reference or delete an item. Add a "⋯" menu in the practice header and a right-click menu on Today and Library rows:
   - Rename…
   - Artist & key…
   - Pause / Resume
   - Mark as reference
   - Delete, with an Undo toast
4. **Sessions are saved automatically.** The Session row is written when the session ends. "Save to log" only adds the note; "Back to Today" no longer drops the session as it does in the mockup.
5. **The new cap counts new items already started today**, so "3 of 3" can't be bypassed by finishing them.
6. **No metronome and no BPM anywhere**, per Revision 5. The mockup's leftover metronome and BPM state isn't ported.
7. **Instruments:** renaming, recoloring and deleting them isn't in the mockup, so it's left for later (right-click on the chip).
8. **Scales tab on Voice items** (added Oct 7, Chris's request). A piano plays a vocal warm-up: the chord, then the pattern to sing along with, then up a half step, across the starting notes you pick. Six major patterns, Up / Down / Up & back, and Slow / Medium / Fast (words, no BPM). Hold a key on the keyboard to hear one note. It uses the General MIDI piano built into macOS (`AVAudioUnitSampler`), so nothing is bundled. The settings are one global preference, not per item, so there's no schema change. Logic is in `SustainCore/Scales`; tested on Linux.

## Milestones (each ends with something Chris uses)

**M0: daily loop (the app replaces Notion)**
1. **YouTube spike, first** (biggest risk): embed plays in a sandboxed SwiftUI `WebView` (or `WKWebView`), the loop is accurate to ±0.1 s, and we know which speeds YouTube honors.
2. **Scaffold:** `project.yml`, the Core package, both CI workflows, and a themed empty window on macOS.
3. **Core:** dates, areas (nameKey, matching, ranking, ops), FSRS + scheduler with fixtures, Today queue, lane rules, streak, theme + contrast, YouTube URL. All green on Linux.
4. **Store:** SchemaV1, Seeder (instruments and 19 areas, once), MediaStore, ItemStore / AreaStore / ReviewStore. App tests green on macOS CI.
5. **Shell:** sidebar, navigation, instrument filter, toast, theme and mode.
6. **Capture**, the full spec including attachments saved to disk.
7. **Today**, including Done today and Re-rate (rollback, then reopen).
8. **Practice card** with the Video tab, notes, progress, rating, keys and skip. Finishing the queue returns to Today with a toast.
9. **Library.**
10. **Settings:** Appearance, Scheduling, Instruments, Areas; JSON export.

Done when: Chris captures in under 30 s, practices a full Today with keys only, and the queue is right after a day rollover.

**M1: media + notes**
- PDF tab, Images tab (paste, drop, Quick Look) and playback of attached audio on the Takes tab
- ~~Drop and paste on the practice card~~ (pulled into M0 on Oct 7; see `docs/FRICTION.md`)
- `/` insert in notes, and links

**M2: sessions + log**
- Persisted session timer
- Session complete dialog
- Log screen, heatmap, streak from real reviews

**M3: data + migration**
- Recording takes
- The Notes screen
- `.sustain` zip backup and restore, daily folder backup
- Notion CSV import with the area-mapping preview (Interval + Last Practiced seed the FSRS card; Warm-Up → warm-up lane; FOCUS → focus lane)

**M4: grow**
- iCloud sync (SwiftData + CloudKit, paid developer account)
- Developer ID + notarized DMG
- Practice packs
- FSRS parameter optimizer from review history
- iPad

**Later, only if wanted:** metronome, tempo tracking, more palettes.

## Verification
- **Core (Swift Testing, Linux + macOS):** every test listed in `docs/PLAN.md` › Verification for the scheduler, Today, areas and backup, ported 1:1. Plus:
  - **FSRS parity:** about 200 generated rating sequences from ts-fsrs 5 (short-term off, no fuzz, retention 0.9 / max 60 and two other settings). Stability and difficulty match within 1e-6; due days match exactly.
  - **Theme parity** against the mockup fixture, and the contrast gate for both modes.
  - **Streak and heatmap** across a DST change and the year boundary.
  - **New cap** with new items already started today.
  - **Day rollover:** the same items with `now` moved past midnight.
- **App (XCTest, in-memory store):**
  - seeds run once, and a deleted seed is not re-added
  - AreaStore rename / merge / delete / undo against real models
  - re-rate on the same day leaves one review
  - leaving warm-up makes the item due tomorrow
  - MediaStore copy, delete and orphan cleanup
  - JSON export → wipe → import round-trip
- **UI (XCUITest),** the Playwright flows from PLAN.md:
  - ⌘K, a name, Enter → a New row with no dangling "·"
  - type "Slap", Enter → a dashed chip; Enter again → saved with area Slap
  - Esc twice creates no area
  - ⇧Enter keeps instrument, area and lane
  - deleting a used area keeps its item in Today, and Undo restores it
  - add → New → press 3 → Done today → back in Today when due (fake clock via a launch argument)
- **Screens:** CI snapshots of every screen in light and dark, checked side by side with the mockup boards before each milestone is called done.
- **Manual, per milestone:**
  - a keyboard-only pass
  - VoiceOver labels on Today, the practice card and Capture
  - YouTube loop and speed on 3 real lesson videos
  - a light/dark switch while the app is open

## Risks
- **YouTube in a web view:**
  - Embeds without a referrer fail (errors 152/153). Load `player.html` with an https `baseURL` and pass `origin` / `widget_referrer`.
  - Not every speed may be honored. If 60 % or 85 % get rounded, show only the rates `getAvailablePlaybackRates()` returns between 50 and 100 %.
  - Settled by the step 1 test (Oct 6): the referrer setup works, and 60 % and 85 % are honored.
- **Writing SwiftUI without a Mac in the loop:** mitigated by the thin app layer, macOS CI on every app PR, and the PNG snapshots.
- **Arrow and Enter keys in a focused SwiftUI `TextField`** may not reach `.onKeyPress` on macOS. Fallback: a small `NSTextField` wrapper that handles `moveUp`, `moveDown`, `insertNewline` and `cancelOperation` in `doCommandBy`, used only by `AreaPicker` and Capture.
- **SwiftData quirks:** keep queries simple and filter in memory (a few thousand items at most). All writes go through the Store types, so swapping to GRDB later would touch only `App/Store`.

## Decisions (Chris, Oct 6)
1. **Fonts:** SF Pro + SF Mono, the same fonts the mockup renders.
2. **Minimum macOS:** 26. Chris is on it and is the only user until M4. If the app is ever shared with people on older Macs, lowering the target means replacing the macOS 26-only APIs, so keep them inside small wrappers.
3. **Schedule control in Capture:** stays visible, as in the mockup.
