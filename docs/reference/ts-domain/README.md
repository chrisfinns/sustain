# TypeScript reference (porting source, not app code)

These modules come from the short-lived web version of Sustain, before the switch to a native SwiftUI Mac app. Keep them only as a reference when porting the same rules to Swift; the Swift code is the source of truth.

- `areas.ts`: `nameKey` folding (case, punctuation, trailing plural "s"; keeps `#` and treats ♭ as `b`), name validation, the 19 seed areas, `SEED_SUGGEST`, `rankAreasForCapture` (6 chips) and `matchAreas` (exact → prefix → substring → typo; warm-up row; Create row).
- `scheduler.ts`: the ts-fsrs 5 wrapper: days only (`enable_short_term: false`), no fuzz, retention 0.9, and the 60-day cap enforced again after the engine, because the engine can land one day past it. Also `preview`, interval labels and stage names.
- `dates.ts`: local calendar-day helpers.
- `youtube.ts`: video id and start-time parsing for every common YouTube URL shape.
- `types.ts`: the data model as it stood (Item, Area, Instrument, Review, Attachment, Settings).

Port the behavior together with the tests listed in `docs/PLAN.md`. Don't port the file layout.
