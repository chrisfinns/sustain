# Sustain: a spaced-repetition practice app for musicians

> **Oct 6: Sustain is now a native macOS app.** The build plan is `docs/SWIFT_PLAN.md`. It replaces this file's Delivery, Stack, Structure, Roadmap and Verification sections (PWA, Dexie, React). The product rules here still apply: principles, Areas, Warm-up lanes, scheduler semantics and Visual design.

## Context
Chris's Notion "Guitar Tracker" template (Guitar Knowledge DB, Practice Log, Daily Practice Session, 🟢 Good / 🔴 Again buttons) works, but it's stuck inside Notion: it's guitar-only, needs formula and button setup, and the practice session has to be built by hand. Goal: a standalone **"Anki for any instrument"** that's easy to use, with media (PDF, screenshots, YouTube, recordings) and notes inside each item.

Decisions made:
- **No server, no accounts, no cloud DB.** All data lives on the user's machine.
- **Laptop/desktop first.**
- **FSRS scheduler with 4 buttons.**
- **Instruments:** guitar, bass, piano/keys, drums, voice.
- **Areas are optional and user-editable** (feedback on the mockup): at most one area per item, and you can skip it. Pick from suggestions or type a new one. Rename, recolor, merge or delete areas in Settings.
- **Warm-up is a per-item setting, not an area:** Regular / Focus / Warm-up, which replaces the Focus checkbox. Changing areas can never change Today.

Repo: `chrisfinns/sustain`, branch `main`. So far it only has `docs/PLAN.md`. The mockup is at https://claude.ai/artifact/TSe1AHctNW6q3tCF7dqDYC (source in the scratchpad at `sustain-canvas/project/Main.dc.html`).

## Revision 5 (done Oct 6): canvas comment round, simplifying v1
Chris left 8 comments on the canvas. Decisions, now applied to the mockup:
- **Today:** removed the "N to practice · about N min" line. The streak chip stays.
- **Practice card:**
  - Notes are one **freeform text** per item (TipTap doc in the real app; `/` inserts image, PDF, YouTube or recording). They save as you type.
  - **No metronome in v1.**
  - **No tempo tracking in v1:** no "clean at" BPM, no best/target BPM, no BPM on Today rows, in Library or in Capture.
  - **YouTube embed + A–B loop + speed control: keep, and move into M0.**
- **Capture:**
  - "+ Instrument" inline, which creates and selects the instrument. Settings › Instruments "+ Add instrument" works too. A custom instrument gets general area suggestions.
  - The Media box became a freeform **Notes & media** area: free text plus any number of attachments (paste screenshots with Ctrl V, drop PDFs, images or audio, remove with ×). On save, the text goes to the item's notes, images to Images, PDFs to Tab/PDF, audio to Takes.
  - The lane control is now labeled "Schedule", with plain hints: Regular = "comes back right before you'd forget it…".
  - Open question to Chris: hide Schedule behind "More options" (Regular by default)? Answered Oct 6: no, it stays visible.

## Revision 4: canvas comment "remove" on Today's summary line
A canvas comment from Chris on 1 · Today, anchored to the text `{{ summaryLine }}` (the "9 to practice · about 27 min" line under the Today title), says "remove".

1. Load the `ArtifactComments` tool and read thread `116f1a50-b835-4e34-aa91-6a3b83a3a164`. Also reply to any other threads marked as sent to me.
2. Re-read the live `project/Main.dc.html` (`action: "read"`), since Chris may have edited it, and diff it against the scratchpad copy. If it changed, work on the live copy.
3. In the Today header, delete the `<span>{{ summaryLine }}</span>`. Keep the streak chip in that row, the Time budget control and the Start session button. Also drop the now-unused `summaryLine` from `renderVals()`.
4. Re-run the gates (`check.py` with `node --check` and template names, the harness for all start × palette × mode, and the contrast check), then publish only `project/Main.dc.html` to the same URL.
5. Update the Today wireframe in the plan (remove "12 due - 3 new - ~24 min"), copy it to `docs/PLAN.md`, commit and push.
6. Reply in the thread with a one-line note: "Removed the '… to practice · about … min' line from Today's header; the streak chip stays." Then resolve the thread. In the session, write one short line.

## Revision 3: lock in Paper & Ink ("soft clay")
Chris picked **soft clay**, which is the dark half of **Paper & Ink**: ink #1A1917, cream text #EDE6D6, clay accent #E8876D. The light half, paper #F5F1E8 with red clay #A9412A, is used when the computer is in light mode, and mode stays **System**. Chris will make detailed edits directly on the canvas, so **their edits win**: read before every publish and never overwrite them.

Steps:
1. **Read the live canvas first.** Use `action: "read"` for `project/canvas.json` and `project/Main.dc.html` in case Chris has already started editing, and apply my changes onto those versions.
2. **Make Paper & Ink the default in `Main.dc.html`:**
   - `data-props.palette.default` → `"paper"`;
   - `paletteNow()` fallback `'studio'` → `'paper'`;
   - `buildTheme`'s unknown-dir fallback → `paper`;
   - put Paper & Ink first in `themeBases()`, so it is the first card in Settings › Appearance.
   Mode default stays `system`.
3. **Canvas index:**
   - `launch` → `{view: 'canvas', page: 'screens'}`, since that's where the edits happen;
   - Color schemes page note → "Color schemes · chosen: Paper & Ink (soft clay)";
   - keep the 8 boards there for reference.
4. **Re-run the gates** (`node --check`, template names for every start × palette × mode, the interaction harness, contrast), then publish only the changed files to the same URL.
5. **Add a "Visual design" section to `docs/PLAN.md`:**
   - palette with the base hexes for both modes;
   - the derived token list;
   - fonts: Instrument Sans for UI, IBM Plex Mono for numbers;
   - contrast rules: text ≥ 7:1, small text ≥ 4.5:1, dots ≥ 3:1;
   - "area/instrument colors are names, resolved per mode";
   - in the real app, tokens become CSS custom properties set on `:root` for `prefers-color-scheme`, plus a manual override.
   Then commit and push to `main`.
6. **When Chris says his edits are done:**
   - read every changed `.dc.html` from the canvas (`list` with `scope: "files"`, then `read` with `path`);
   - diff against the scratchpad copies;
   - summarize what changed and fold it into the plan before M0.

## Revision 2: color scheme, "show me"
Chris asked to see the color directions and chose **both modes, following the system setting**. So the mockup becomes themeable, and a "Color schemes" page on the canvas shows the Today screen in all 4 directions × dark and light (8 boards) to pick from.

**1. Tokenize `Main.dc.html`.** Today it has 53 distinct hardcoded hexes (379 uses in the markup, 133 in JS).
- A Python script maps each hex to a semantic token and rewrites it as `{{ t.<token> }}`. Style holes are allowed because palette and mode are declared tweak props.
- JS color literals become `T.<token>`.
- Tokens:
  - Ground and surfaces: `bg`, `side`, `dim`, `surf`, `surf2`, `surf3`, `raised`, `raised2`, `track`, `sel`, `sel2`, `sel3`
  - Lines: `line`…`line6`, `sideLine`
  - Text: `text`, `textSoft`, `muted`, `faint`, `disabled`
  - Accent: `accent`, `onAccent`, `accentTint`, `accentTint2`, `accentLine`, `heat1`, `heat2`
  - Ratings: `again`/`hard`/`good`/`easy`, each with a `…Line` and `…Tint`
  - Status: `violet`, `violetTint`
  - Overlays: `overlay`, `shadow`
- The video box and the PDF page keep fixed colors in both modes, since a player is black and paper is light. That block is handled before the global replace.
- **Area and instrument colors become token names**, as the plan's data model already says: amber, coral, rose, violet, blue, teal, green, slate. They resolve to a dark-mode or light-mode hex. `seedAreas`, `instMeta` and `palette()` store names; `cycleColor` and `leastUsedColor` work on names.

**2. Theme generator** (`themes()` + `buildTheme(dir, mode)`):
- Each direction defines only base colors per mode: `bg`, `surf`, `text`, `accent`, `onAccent` and the 4 rating colors.
- Everything else is derived:
  - Dark mode: surfaces, fills and lines mix `bg` toward `text` (2–30%).
  - Light mode: card surfaces mix `bg` toward white; fills and lines mix toward `text`.
  - Tints: a mix of 14–18% rating or accent color.
- **Directions:**

  | Direction | Mode | Background | Text | Accent |
  |---|---|---|---|---|
  | Studio Night | dark | #111113 | #ECE8E1 | #F0A73A |
  | Studio Night | light | #F4F2EE | #1B1A18 | #A85F00 |
  | Analog Console | dark | #17181A | #E9E4D8 | #E8833A |
  | Analog Console | light | #EFEBE3 | #22201C | #B4531A |
  | Circuit | dark | #0B0B0B | #F5F5F2 | #FF5B1F |
  | Circuit | light | #F2F2EF | #0B0B0B | #D93D00 |
  | Paper & Ink | light | #F5F1E8 | #1D1C1A | #B4462B |
  | Paper & Ink | dark | #1A1917 | #EDE6D6 | #E07A5F |

  Light-mode ratings are darker (for example Again #B83A2E, Hard #8A6100, Good #2D54C4, Easy #1E7A5E).
- **Contrast gate (harness):**
  - for every theme: text/bg ≥ 7, muted and faint on every surface ≥ 4.5, rating and accent text on surf and tints ≥ 4.5, onAccent/accent ≥ 4.5;
  - data dots ≥ 3 against their surface;
  - any failure is adjusted before publishing.

**3. Props and Settings:**
- Replace the `accent` tweak with `palette` (studio | console | circuit | paper, default studio) and `mode` (system | dark | light, default system).
- `system` reads `matchMedia('(prefers-color-scheme: dark)')` inside try/catch and updates live through a change listener added in componentDidMount and removed on unmount.
- New **Settings › Appearance** section with 4 palette cards (swatches + name) and a System / Dark / Light segmented control. These are state overrides, like Simple mode.

**4. Canvas:**
- Add `pages`: Screens (the existing 9 boards) and Color schemes.
- 8 new tiny wrapper boards, `Colors-<dir>-<mode>.dc.html`, each `<dc-import name="Main" start="today" palette=… mode=…>`.
- Grid layout: 4 columns (directions) × 2 rows (dark, light), each board 1440×900.
- Title note: "Pick a color scheme".
- `launch: {view: 'canvas', page: 'colors'}`.

**5. Verification:**
- `node --check`, plus the template-names check for every start × palette × mode.
- The existing 53 interaction checks still pass.
- New: the contrast gate for all 8 themes, and a guard that no stray hex is left in the markup outside the fixed video/PDF block.
- Republish to the same URL. After Chris picks a direction, record it in `docs/PLAN.md` (new "Visual design" section), then commit and push.

## This revision: what gets done now
1. Update the clickable mockup (`Main.dc.html`) to the new Capture, Areas and Warm-up design (see "Mockup changes" below), then republish to the same Artifact URL.
2. Copy this plan to `docs/PLAN.md`, commit and push to `main`.
3. No app code yet. M0 still waits for sign-off on the mockup.

## Product principles
1. **Today is the home screen.** Open the app and the list is already built.
2. **Rating is one keystroke.** Keys 1–4, and each button shows its next interval ("Good · 4d").
3. **Don't rebuild Notion.** Notes and media serve the practice card. No nested pages and no user-defined databases.
4. **Enforce "start small" in the app.** A daily cap on new items (default 3).
5. **Private by design.** Nothing leaves the device. Backup is the user's job, so the app makes backups trivial.

## Delivery: local-first PWA (no backend)
- Static files only (GitHub Pages or Cloudflare Pages). Open the link and it works. It can be installed as a desktop app (dock icon, offline) from Chrome or Edge.
- Data in IndexedDB (records + file blobs), with `navigator.storage.persist()` requested on first run.
- Same codebase can be wrapped in **Tauri** later (M4) for a downloadable app with real files on disk.

## Core loop
1. **Capture (under 30s):** Cmd/Ctrl+K, type a name, press Enter. That's all that's required. The instrument is preselected, the area is optional, and the setting defaults to Regular. Paste a YouTube URL, drop a PDF, or paste a screenshot straight in.
2. **Today:** Warm-ups, then Focus, then Due (most overdue first), then New (capped). Optional "I have 20 min" budget that trims the list.
3. **Practice card (desktop split view):** media on the left (YouTube with A-B loop and 50–100% speed, PDF/tab viewer, images, recorded takes), freeform notes on the right. Rate with 1–4. No metronome or tempo tracking in v1.
4. **Auto-logged session:** items rated, minutes, BPMs, and a closing note. This replaces the manual Practice Log page.

## UI (desktop wireframes)
Shell: a left sidebar (Today, Library, Notes, Log, Settings, instrument filter, Capture) and the main pane on the right. The app follows light/dark mode.

**1. Today (home)**
```
+--------------+---------------------------------------------------------+
| SUSTAIN      | Today - Tue Oct 6           [20 min v]  [> Start session]|
|              | 9-day streak                                            |
| > Today   12 |                                                         |
|   Library    | WARM-UP                                                 |
|   Notes      |  o Spider exercise         Guitar - Technique   80 bpm  |
|   Log        |  o Lip trills              Voice                        |
|   Settings   | FOCUS                                                   |
|              |  * Cliffs of Dover solo    Guitar - Repertoire  2d late |
| INSTRUMENTS  |  * Paradiddle-diddle       Drums  - Rudiments   due     |
|   All        | DUE                                                     |
|   Guitar   8 |  o Minor pentatonic box 1  Guitar - Scales      5d late |
|   Bass     2 |  o ii-V-I voicings in Bb   Piano  - Voicings    due     |
|   Piano    1 | NEW  (3 of 3 today)                                     |
|   Drums    1 |  + Hysteria bass intro     Bass   - Repertoire          |
|   Voice    0 |                                                         |
| [+ Capture]  | DONE TODAY (2)                                 [show v] |
+--------------+---------------------------------------------------------+
```

**2. Practice card** (opens from Start session or by clicking an item; ←/→ moves between items)
```
+------------------------------------------------------------------------+
| <- Today  Cliffs of Dover solo - Eric Johnson   Guitar - Repertoire  *  |
| 3 of 12  [=======-------------]     14:32     Key E - target 160 bpm    |
+------------------------------------------+-----------------------------+
| [YouTube] [Tab.pdf] [Images 2] [Takes 3] | NOTES                       |
| +--------------------------------------+ | - Watch the slide at 1:12   |
| |                                      | | - Pick hand: stay loose     |
| |              > video                 | |                             |
| |                                      | | Last: Oct 1 - Hard @ 132    |
| +--------------------------------------+ | Best clean: 140 bpm         |
| A 1:04 ---[#########]------ B 1:22 Loop  |                             |
| Speed  50  75 [85] 100 %                 | METRONOME                   |
|                                          |  - [140] +  tap  * * o o  > |
|                                          | [o Record take]             |
+------------------------------------------+-----------------------------+
| Clean at [140] bpm                                                     |
|  [1 Again - 1d]   [2 Hard - 3d]   [3 Good - 8d]   [4 Easy - 15d]       |
+------------------------------------------------------------------------+
```

**3. Capture (Cmd/Ctrl+K)**
```
+- Capture ------------------------------------------------ esc -+
| Name    [Hysteria bass intro                                 ] |
| Instr.  ( Guitar ) (*Bass ) ( Piano ) ( Drums ) ( Voice )      |
| Area  optional                                                  |
|   (Repertoire) (Grooves) (Scales) (Walking Lines) ...           |
|   [+ Type an area...]   -> matches..., Create "Slap"            |
| Target bpm [94]    ( Regular | Focus | Warm-up )                |
| +------------------------------------------------------------+ |
| | Paste a YouTube link, or drop a PDF / image here            | |
| | youtube.com/watch?v=...                     embedded ok     | |
| +------------------------------------------------------------+ |
|                              [Add  Enter]  [Add & practice]    |
+----------------------------------------------------------------+
```

**4. Library**
```
| Library  [search...]  Instrument [All v]  Area [All v]  Status [Active v] |
| Name                    Instr.   Area        Status     Next      BPM     |
| Cliffs of Dover solo    Guitar   Repertoire  Learning   in 8d    140/160  |
| Minor pentatonic box 1  Guitar   Scales      Review     overdue    -      |
| Major chord chart       Guitar   Chords      Reference    -        -      |
| Moby Dick fill          Drums    Fills       Paused       -        -      |
```

**5. Session complete** (also saved to Log)
```
+- Session complete --------------------------------+
| 26 min - 9 items - 6 Good - 1 Easy - 1 Hard - 1 Again |
| Oct  [ ][ ][#][#][ ][#][#][#][#]   9-day streak   |
| Note [Left hand tired after the solo run...     ] |
|                                         [Save]    |
+---------------------------------------------------+
```

## Visual design (decided Oct 6)
- **Palette: Paper & Ink.** It follows the computer's light/dark setting, with a manual System / Dark / Light override in Settings › Appearance.

  | Mode | Background | Text | Accent | On accent | Again | Hard | Good | Easy |
  |---|---|---|---|---|---|---|---|---|
  | Dark ("soft clay") | ink #1A1917 | cream #EDE6D6 | soft clay #E8876D | #1A0A05 | #E8806E | #E2B65A | #86A8F0 | #6CC4A4 |
  | Light | paper #F5F1E8 | ink #1D1C1A | red clay #A9412A | #FFFFFF | #B23A2E | #835C00 | #2D54C4 | #1A715A |

- **Only those base colors are hand-picked.** Everything else is derived:
  - Dark mode: surfaces, fills and lines mix bg toward text (2–30%).
  - Light mode: cards mix bg toward white; fills and lines mix toward text.
  - Tints: 10–18% of a rating or accent color.
  - Token names: `bg side dim surf surf2 surf3 raised raised2 track sel sel2 sel3 line…line6 text textSoft muted faint disabled accent onAccent accentTint accentTint2 accentLine heat1 heat2 again/hard/good/easy (+Line, +Tint) violet violetTint overlay shadow`.
- **Area and instrument colors are names** (amber, coral, rose, violet, blue, teal, green, slate), resolved to a readable hex per mode.
- **Fixed colors:** the video player stays black and the PDF page stays paper in both modes.
- **Contrast rules**, enforced by a test over every theme:
  - body text ≥ 7:1 on bg
  - all small text ≥ 4.5:1 on every surface it sits on
  - text on accent ≥ 4.5:1
  - color dots ≥ 3:1
- **Type:** SF Pro for UI, SF Mono for numbers (timers, intervals, counts), the same fonts the mockup renders. Changed Oct 6 from Instrument Sans + IBM Plex Mono.
- **In the real app:**
  - Tokens become CSS custom properties on `:root`, with dark/light sets switched by `prefers-color-scheme` and a `data-theme` override.
  - Tailwind's theme maps to those variables.
  - The theme generator lives in `src/ui/theme.ts`, with a `theme.test.ts` contrast gate.
  - The other three directions (Studio Night, Analog Console, Circuit) stay in the mockup only for reference.

## Scheduler: FSRS via `ts-fsrs` (MIT, open-spaced-repetition)
- Buttons with musician meanings (shown as tooltips):
  - **Again**: fell apart
  - **Hard**: got through it slow or with mistakes
  - **Good**: clean at target tempo
  - **Easy**: clean, effortless, at or above tempo
- Defaults: `request_retention 0.9`, **`maximum_interval 60`** (keeps the "don't find out on stage" cap), **`enable_short_term false`** (practice works in days, not Anki's 1m/10m steps).
- Re-rating the same day: undo the earlier review with `ts-fsrs` rollback, then apply the new one, so ratings don't compound.
- **Simple mode** toggle in Settings shows only Again/Good, for people who want the blog's 2-button flow. Same engine underneath.
- Status is mostly derived from the FSRS card state: New, Learning, Review, Mastered (stability ≥ max). The user sets only **Paused** and **Reference**.
- Isolate everything in `src/domain/scheduler.ts` so the engine can be swapped or tuned later (e.g. a per-item "gig-ready" higher retention).

## Areas (optional, user-editable)
- **One global list, no instrument field.** "Scales" exists once and works on guitar, bass and piano.
- **Duplicates are blocked by a `nameKey`.** It ignores case and punctuation and treats a trailing plural "s" as the same name, but keeps musical symbols:
  - Warm-Up = warm ups
  - Techniques = Technique
  - B♭ voicings = Bb voicings
  - C# major ≠ C major
- **Areas are labels only.** No area has behavior, and `today.ts` never reads areas.
- **Capture:**
  - The area row is labeled "optional" and nothing is preselected.
  - Up to 6 chips are ranked for the chosen instrument: areas you've used on it most, then seed suggestions. The ranking is computed when Capture opens or the instrument changes, so chips never jump while you click.
  - Click a chip to pick it; click it again to clear it.
  - One type-ahead box searches all areas, forgives typos ("Repertiore" → Repertoire) and offers `Create "X"`. A new area shows as a dashed "Slap · new" chip.
  - The new area is saved only together with the item, so cancelling leaves no orphan area.
  - Typing "warm up" offers "Make this a daily warm-up", which sets the Warm-up setting instead of creating an area.
  - Switching instrument keeps the chosen area.
- **Capture keys:**
  - Enter with text in the box: commits the highlighted match.
  - Enter with the box empty: saves.
  - Shift+Enter: saves and keeps instrument, area and setting, for adding several items in a row.
  - Esc: clears the text, and a second Esc closes.
- **Settings › Areas is the only place to manage them:**
  - Rows are alphabetical: color swatch (8 palette colors), inline-editable name, item count (links to the Library filter), trash.
  - "+ Add area" row at the end.
  - Renaming onto an existing name asks inline to merge them.
- **Delete has no dialog.** The area's items get no area, nothing in the schedule changes, and a 10-second toast offers Undo.
- **Labeling after capture:**
  - The practice card header shows the area (or "+ Area"), which opens the same picker.
  - Library gets an Area filter that includes "No area", with "Manage areas…" at the bottom.
  - Today's meta line drops the area when there is none, so no dangling "·".
- **Seeds (19, inserted once and never re-added after delete):** Repertoire, Technique, Ear Training, Transcription, Songwriting, Scales, Chords, Licks, Fretboard, Jam, Grooves, Walking Lines, Voicings, Sight-Reading, Rudiments, Fills, Independence, Lyrics, Range & Breath.
- **First-day chip order per instrument** comes from a static map in code (e.g. Drums: Repertoire, Rudiments, Grooves, Fills, Independence, Technique).
- **All area writes go through one module, `src/domain/areas.ts`.** It is used by Capture, Settings, the practice card, Notion import, backup restore and practice packs, and holds:
  - `ensureArea`, `renameArea`, `mergeArea`, `deleteArea`, `undoAreaChange`;
  - `repairReferences`, which fixes dangling or duplicate areas after a restore;
  - the pure ranking and matching functions `matchAreas` and `rankAreasForCapture`.
- **Not in M0:** several areas per item, drag reorder, Restore defaults, bulk edit.

## Warm-up as a per-item setting (`lane`)
- `lane: 'normal' | 'focus' | 'warmup'` replaces the `focus` boolean.
- **Today:**
  - Warm-up: lane warmup, not paused or reference, not rated today. Always first; ignores the due date.
  - Focus: lane focus and due.
  - Due: lane normal and due, most overdue first.
  - New: new items that aren't warm-ups, capped per day.
  - A warm-up never takes a New slot and never shows in two sections.
- **Rating a warm-up** still logs a review (BPM, streak), and same-day re-rate still rolls back.
- **Moving a reviewed warm-up back to Regular** makes it due tomorrow, so daily reps can't push it out for weeks.
- **Where the setting is changed:** Capture, the practice card (the Focus star becomes a Regular / Focus / Warm-up menu), and Notion import ("Warm-Up" → warm-up, which wins over FOCUS).

## Data model (Dexie / IndexedDB)
- `instruments` {id, name, icon, color}, seeded: Guitar, Bass, Piano/Keys, Drums, Voice
- `areas` 'id, &nameKey': {id ('seed-<slug>' or 'ar_<ulid>'), name (1–32 chars), nameKey, color (one of 8 palette tokens; a new area gets the least-used one), seedKey?, createdAt}
- `instruments` are user-addable (name + color token); a custom instrument gets general area suggestions
- `items` {id, title, instrumentId, **areaId (string or null)**, **lane**, paused, reference, artist, key, source, tags[] (import only, read-only), fsrsCard (due, stability, difficulty, reps, lapses, state, last_review), notesDoc (TipTap JSON, freeform), createdAt}. No BPM fields in v1; Notion's BPM is ignored on import.
- `meta` {key, value}: `seededAreas`, `schemaVersion`. Null isn't indexed in IndexedDB, so "No area" is filtered in memory.
- `attachments` {id, itemId?, noteId?, kind: pdf|image|audio|video|youtube|link, blob?, url?, meta (yt loopA/loopB/speed, pdf lastPage)}
- `reviews` {id, itemId, sessionId, rating, bpm?, at, fsrsLog}, the source for undo and later FSRS parameter optimization
- `sessions` {id, startedAt, endedAt, durationSec, noteDoc}
- `notes` {id, title, doc, tags, instrumentId?}: general practice notes, resources, and journal

## Stack
- React + TypeScript + Vite, `vite-plugin-pwa`, Tailwind, React Router
- Dexie + `dexie-react-hooks` (`useLiveQuery`)
- `ts-fsrs` scheduler
- TipTap notes with custom nodes for YouTube, PDF, image, and recording
- `pdfjs-dist` viewer; YouTube IFrame Player API (`seekTo`, `setPlaybackRate`) for A-B loops
- MediaRecorder for self-recording (no metronome in v1)
- Keyboard shortcuts: 1–4 rate, Space play/pause, L loop, Cmd+K capture
- **Backup:** export/import a `.sustain` zip (JSON + blobs, via `fflate`). In Chrome/Edge, optional auto-backup to a folder the user picks (File System Access API).
- Tests: Vitest (domain) + Playwright (e2e, Chromium at /opt/pw-browsers)

## Structure
```
src/domain/scheduler.ts   ts-fsrs wrapper: rate, undo, preview intervals (+ tests)
src/domain/today.ts       builds Today queue from lane + FSRS (never reads areas)
src/domain/areas.ts       the only area write path + nameKey, matching, ranking (+ tests)
src/db/schema.ts          Dexie tables, migrations, seed instruments/areas
src/db/backup.ts          zip export/import
src/features/{today,capture,item,library,notes,log,settings}/
src/components/media/{YouTubePlayer,PdfViewer,ImageGallery,Recorder}.tsx
src/components/tools/{Metronome,Timer}.tsx
```

## Roadmap
- **Step 0, clickable mockup (first thing after approval):** a single-file HTML prototype of the 5 screens above with fake data, published as a private Artifact. Sign-off on the look before any app code.
- **M0, usable daily (about 1 week):**
  - scaffold, schema + seeds, scheduler + tests
  - quick-add (optional area, type-to-create, schedule, add instrument, freeform notes + multiple pasted/dropped attachments)
  - Settings › Areas (rename, recolor, merge, delete + undo)
  - Library (filter by instrument, area, "No area")
  - Today, 4-button rating with keys, Done Today
  - **YouTube embed with A–B loop + speed**
  - JSON backup export
- **M1, media + notes:** PDF viewer, image gallery, links, TipTap notes with `/` inserts
- **M2, practice tools:** session timer + log, calendar heatmap/streak
- **Later, only if wanted:** metronome, tempo tracking (target / best clean BPM, BPM on rows)
- **M3, data + migration:** recordings, general Notes, full zip backup + folder auto-backup, **Notion CSV import** (Name/Area/Status/BPM/FOCUS/Artist/Key/Source; Interval + Last Practiced seed FSRS stability and due). It shows an area mapping preview first. For your 11 Notion areas: 9 match exactly, Techniques → Technique, Warm-Up → the Warm-up setting, and no new areas are created, PWA offline polish
- **M4, grow:** Tauri desktop build, shareable "practice pack" files (a teacher or course exports a set of items), FSRS parameter optimizer from review history

## Mockup changes (this revision, `Main.dc.html` only; the 7 wrapper artboards stay as they are)
- **Data:**
  - Replace `areaMeta()` with `seedAreas()` (19 rows {id, name, color, seedKey}) in `state.areas`, plus a static `SEED_SUGGEST` per instrument.
  - Add helpers `nameKey`, `areaById`, `matchAreas`, `rankAreas`.
  - Seed items get `areaId` and `lane`:
    - Spider exercise: Technique + warmup.
    - Lip trills: no area + warmup.
    - Breathing: no area.
    - Little Wing and Paradiddle-diddle: `lane: 'focus'`.
  - Remove `kind: 'warm'` and `focus`.
- **Queue:** `computeQueue` uses lane (warm-up / focus / normal); new items exclude warm-ups. `chipFor`, `libStatusChip` and `libNext` read lane.
- **Meta lines** in Today, the practice header and Library join instrument · area (only if set) · artist.
- **Capture:**
  - "Area · optional" with up to 6 toggle chips (computed when Capture opens or the instrument changes), a dashed "X · new" chip, the type-ahead input and its suggestion list (warm-up row, matches with an instrument hint, `Create "X"`).
  - The Regular / Focus / Warm-up segmented control replaces the checkbox; the footer hint follows it.
  - Keys: Enter, Shift+Enter, Esc, ↑/↓, Backspace as specified above.
  - Instrument switch keeps the area.
  - The toast mentions a new area.
- **Library:** Area filter (All, No area, each area with counts, Manage areas…), a color dot in the Area column, and search that covers area names.
- **Settings › Areas section:**
  - swatch that cycles colors, inline rename, merge on collision, count, trash, and a "+ Add area" row;
  - the toast gets an Undo action (10 s);
  - the Instruments chips show item counts.
- **Practice header:**
  - the area label becomes a button ("+ Area" when empty) that opens the same picker;
  - the Focus star becomes a lane menu.
- **Start prop:** add `capture-new`, which opens Capture with "Slap" typed and Create highlighted. The existing `capture` start uses Grooves + Focus.

## Verification
- `scheduler.test.ts`:
  - new card rated Good → due in ≥1 day
  - Again shortens and Easy lengthens vs Good
  - no interval > 60
  - same-day re-rate == single rating
  - simple mode maps to Again/Good
- `today.test.ts`:
  - overdue ordering, new cap, paused/reference excluded, time budget trims
  - warm-ups come first by lane even with zero areas
  - a warm-up never shows in two sections and never takes a New slot
  - the queue is identical before and after renaming, merging or deleting every area
  - a reviewed warm-up moved to Regular is due tomorrow
- `areas.test.ts`:
  - nameKey cases (Warm-Up = warm ups, Techniques = Technique, B♭ = Bb, C# ≠ C, emoji allowed)
  - validation (empty, punctuation-only, over 32 chars, reserved "No area"/"All areas")
  - `ensureArea` is idempotent and two concurrent calls create one row
  - rename onto an existing name gives a conflict
  - merge, delete and undo restore only the items still affected
  - match highlighting: "Repertiore" → Repertoire, no match → Create
  - ranking: cap 6, selected area pinned, stable order
- `schema.test.ts`: seeds are inserted once, and a deleted seed is not re-added
- `backup.test.ts`: export → wipe → import round-trips items (areaId null, lane, tags), areas, meta, reviews and blobs; restore repairs dangling areas and reports it
- Playwright:
  - Cmd+K, name, Enter → New row shows "Guitar" with no dangling separator
  - type "Slap", Enter → dashed chip without saving; Enter again saves with area Slap
  - Esc twice creates no area
  - Shift+Enter keeps instrument, area and setting
  - deleting a used area keeps the item in Today; Undo restores it
- Playwright smoke with a fake clock: add item → shows as New in Today → press 3 → moves to Done Today → appears in Today when it comes due
- `npm run build`, then serve `dist`, install the PWA, go offline, add a YouTube + PDF item, set a loop, reload, and confirm everything persists
- **This revision (mockup):**
  - In Capture, save with only a name.
  - Type "Slap", press Enter (dashed chip), press Enter again (saved, toast mentions the new area).
  - Typing "warm up" offers the warm-up row.
  - In Settings › Areas, rename one area onto another (merge prompt), delete a used area (Undo toast; the item stays in Today and shows "—" in Library), then press Undo.
  - Switch the setting to Warm-up and the item moves to the top of Today.
  - Before publishing, sanity-check the edited file: every `{{ }}` name used in the markup is returned by `renderVals()`, and run `node --check` on the extracted script.
