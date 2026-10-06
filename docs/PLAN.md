# Sustain: a spaced-repetition practice app for musicians

## Context
Chris's Notion "Guitar Tracker" template (Guitar Knowledge DB, Practice Log, Daily Practice Session, 🟢 Good / 🔴 Again buttons) works, but it's stuck inside Notion: it's guitar-only, needs formula and button setup, and the practice session has to be built by hand. Goal: a standalone **"Anki for any instrument"** that's easy to use, with media (PDF, screenshots, YouTube, recordings) and notes inside each item.

Decisions made:
- **No server, no accounts, no cloud DB.** All data lives on the user's machine.
- **Laptop/desktop first.**
- **FSRS scheduler with 4 buttons.**
- **Instruments:** guitar, bass, piano/keys, drums, voice.

Repo `chrisfinns/sustain` is empty (branch `claude/gallant-gauss-7axdni`, no commits).

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
1. **Capture (under 30s):** Cmd/Ctrl+K quick-add with name, instrument, and area. Paste a YouTube URL, drop a PDF, or paste a screenshot straight in.
2. **Today:** Warm-ups, then Focus, then Due (most overdue first), then New (capped). Optional "I have 20 min" budget that trims the list.
3. **Practice card (desktop split view):** media on the left (YouTube with A-B loop and 50–100% speed, PDF/tab viewer, images), notes on the right, plus a metronome preset to the item's BPM and a record-yourself button. Rate with 1–4.
4. **Auto-logged session:** items rated, minutes, BPMs, and a closing note. This replaces the manual Practice Log page.

## UI (desktop wireframes)
Shell: a left sidebar (Today, Library, Notes, Log, Settings, instrument filter, Capture) and the main pane on the right. The app follows light/dark mode.

**1. Today (home)**
```
+--------------+---------------------------------------------------------+
| SUSTAIN      | Today - Tue Oct 6           [20 min v]  [> Start session]|
|              | 12 due - 3 new - ~24 min                   9-day streak  |
| > Today   12 |                                                         |
|   Library    | WARM-UP                                                 |
|   Notes      |  o Spider exercise         Guitar - Warm-Up     80 bpm  |
|   Log        |  o Lip trills              Voice  - Warm-Up             |
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
| Area    [Repertoire v]   Target bpm [94]   [ ] Focus           |
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

## Data model (Dexie / IndexedDB)
- `instruments` {id, name, icon, color}, seeded: Guitar, Bass, Piano/Keys, Drums, Voice
- `areas` {id, instrumentId?, name, color, isWarmup}, seeded per instrument:
  - Shared: Warm-Up, Repertoire, Technique, Ear Training, Transcription, Songwriting
  - Guitar: Chords, Scales, Licks, Fretboard, Jam
  - Bass: Grooves, Scales, Walking Lines
  - Piano: Pieces, Scales/Arpeggios, Voicings, Sight-Reading
  - Drums: Rudiments, Grooves, Fills, Independence
  - Voice: Vocal Warm-Ups, Songs, Lyrics, Range/Breath
- `items` {id, title, instrumentId, areaId, focus, paused, reference, targetBpm, bestCleanBpm, artist, key, source, tags[], fsrsCard (due, stability, difficulty, reps, lapses, state, last_review), notesDoc (TipTap JSON), createdAt}
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
- Web Audio lookahead metronome with tap tempo; MediaRecorder for self-recording
- Keyboard shortcuts: 1–4 rate, Space play/pause, L loop, M metronome, Cmd+K capture
- **Backup:** export/import a `.sustain` zip (JSON + blobs, via `fflate`). In Chrome/Edge, optional auto-backup to a folder the user picks (File System Access API).
- Tests: Vitest (domain) + Playwright (e2e, Chromium at /opt/pw-browsers)

## Structure
```
src/domain/scheduler.ts   ts-fsrs wrapper: rate, undo, preview intervals (+ tests)
src/domain/today.ts       builds Today queue (warm-ups, focus, due, new cap, time budget)
src/db/schema.ts          Dexie tables, migrations, seed instruments/areas
src/db/backup.ts          zip export/import
src/features/{today,capture,item,library,notes,log,settings}/
src/components/media/{YouTubePlayer,PdfViewer,ImageGallery,Recorder}.tsx
src/components/tools/{Metronome,Timer}.tsx
```

## Roadmap
- **Step 0, clickable mockup (first thing after approval):** a single-file HTML prototype of the 5 screens above with fake data, published as a private Artifact. Sign-off on the look before any app code.
- **M0, usable daily (about 1 week):** scaffold, schema + seeds, scheduler + tests, quick-add, Library (filter by instrument/area), Today, 4-button rating with keys, Done Today, JSON backup export
- **M1, media + notes:** YouTube loop/speed, PDF viewer, paste/drop images, links, TipTap notes per item
- **M2, practice tools:** session timer + log, metronome tied to item BPM, BPM progress, calendar heatmap/streak
- **M3, data + migration:** recordings, general Notes, full zip backup + folder auto-backup, **Notion CSV import** (Name/Area/Status/BPM/FOCUS/Artist/Key/Source; Interval + Last Practiced seed FSRS stability and due), PWA offline polish
- **M4, grow:** Tauri desktop build, shareable "practice pack" files (a teacher or course exports a set of items), FSRS parameter optimizer from review history

## Verification
- `scheduler.test.ts`:
  - new card rated Good → due in ≥1 day
  - Again shortens and Easy lengthens vs Good
  - no interval > 60
  - same-day re-rate == single rating
  - simple mode maps to Again/Good
- `today.test.ts`: overdue ordering, new cap, paused/reference excluded, warm-ups always first, time budget trims
- `backup.test.ts`: export → wipe → import round-trips items, reviews, and blobs
- Playwright smoke with a fake clock: add item → shows as New in Today → press 3 → moves to Done Today → appears in Today when it comes due
- `npm run build`, then serve `dist`, install the PWA, go offline, add a YouTube + PDF item, set a loop, reload, and confirm everything persists
