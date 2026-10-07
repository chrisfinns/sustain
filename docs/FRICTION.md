# Friction log: M0 week (Oct 7–14)

Use Sustain for real every day. Whenever something slows you down, annoys you, or makes you reach for Notion, add a line: the date, what you were doing, and what got in the way. Don't solve it in your head; just write it down. Paste lines in from your phone if that's easier.

Review on Oct 14: sort everything into fix-now, M1, or drop.

## Log

- **Oct 7 · Only one video per item.** Learning a song needs the original *and* the instrumental (in Notion: any number of embeds, placed freely). Sustain holds one YouTube video per item.
  - Stopgap: paste the second link into Notes. It won't embed or be clickable yet.
  - Proposal, not approved: the Video tab holds several videos, each with a short label (Original, Instrumental, Lesson…) and **its own A–B loop and speed**, since timings differ between uploads. Chips above the player switch between them, and the tab reads "Video 2". This needs a schema change (SchemaV2), and the migration turns each item's current video into its first entry, so nothing logged this week is lost.
  - Open question: in one session, do you switch back and forth (listen to the original, then play along with the instrumental)? If so, should switching keep your place?
- **Oct 7 · Can't add images or PDFs.** Media could only be added in Capture, which makes *new* items. An existing item had no way to take a file, and the empty states sent you back to Capture.
  - Fixed Oct 7 (pulled forward from M1, as drawn in the mockup): on the practice card, drop files anywhere on the media side, press **+ File**, or press **⌘V** outside the notes to paste a screenshot, or a file you copied in Finder. The Images tab has the mockup's "Paste a screenshot" tile. Other files (Guitar Pro etc.) show under Tab / PDF. A file that can't be stored now says so instead of vanishing.
  - Guitar Pro files: **Open** hands Sustain's *copy* to the default app. On Chris's Mac, .gp, .gp5 and .gp4 open in Guitar Pro 8, but .gpx opens in Xcode (GPX is also the GPS track format). Edits saved in Guitar Pro go to the copy, not the original. Open question: does Chris edit GP files? If so, link to the original instead of copying it.
  - Tests: the unit test for adding to an existing item passes. A UI test for pasting with ⌘V and with the tile is written but hasn't passed yet. The first local run (Oct 7, 12:29) failed 6 of 7 tests: test 2 couldn't click a visible field, then every later launch had no window, while Chris was typing in another app. The fix isn't installed until the suite passes, either on CI or locally with hands off the Mac. Not covered by any test: drag-and-drop, and pasting a file copied in Finder (the sandbox may block that; if so, it now shows "Couldn't add…").
- **Oct 7 · No app icon.** Sustain shows the generic icon in the Dock, so it's hard to spot. Concepts to come from the sidebar's waveform mark (a hit that settles into a long held line).
