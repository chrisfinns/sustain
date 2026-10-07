# Friction log: M0 week (Oct 7–14)

Use Sustain for real every day. Whenever something slows you down, annoys you, or makes you reach for Notion, add a line: the date, the version (bottom of Settings, e.g. 0.3.0 (57)), what you were doing, and what got in the way. Don't solve it in your head; just write it down. Paste lines in from your phone if that's easier.

Review on Oct 14: sort everything into fix-now, M1, or drop.

## Log

- **Oct 7 · Only one video per item.** Learning a song needs the original *and* the instrumental (in Notion: any number of embeds, placed freely). Sustain holds one YouTube video per item.
  - Stopgap: paste the second link into Notes. It won't embed or be clickable yet.
  - Proposal, not approved: the Video tab holds several videos, each with a short label (Original, Instrumental, Lesson…) and **its own A–B loop and speed**, since timings differ between uploads. Chips above the player switch between them, and the tab reads "Video 2". This needs a schema change (SchemaV2), and the migration turns each item's current video into its first entry, so nothing logged this week is lost.
  - Open question: in one session, do you switch back and forth (listen to the original, then play along with the instrumental)? If so, should switching keep your place?
- **Oct 7 · Can't add images or PDFs.** Media could only be added in Capture, which makes *new* items. An existing item had no way to take a file, and the empty states sent you back to Capture.
  - Fixed Oct 7 (pulled forward from M1, as drawn in the mockup): on the practice card, drop files anywhere on the media side, press **+ File**, or press **⌘V** outside the notes to paste a screenshot, or a file you copied in Finder. The Images tab has the mockup's "Paste a screenshot" tile. Other files (Guitar Pro etc.) show under Tab / PDF. A file that can't be stored now says so instead of vanishing.
  - Guitar Pro files: **Open** hands Sustain's *copy* to the default app. On Chris's Mac, .gp, .gp5 and .gp4 open in Guitar Pro 8, but .gpx opens in Xcode (GPX is also the GPS track format). Edits saved in Guitar Pro go to the copy, not the original. Open question: does Chris edit GP files? If so, link to the original instead of copying it.
  - Tests: the unit test for adding to an existing item passes. The UI test for pasting with ⌘V and with the tile passes on CI, along with the other 6 UI tests (run 37571616555, commit 8dd1537). A local run earlier failed 6 of 7 while Chris was using the Mac; UI tests need it to themselves. Installed in /Applications on Oct 7. Not covered by any test: drag-and-drop, and pasting a file copied in Finder (the sandbox may block that; if so, it now shows "Couldn't add…").
- **Oct 7 · Drop highlight wraps the tabs.** Dragging a file onto the media side drew the dashed highlight around the Video / Tab · PDF / Images / Takes row too, not just the panel underneath.
  - Fixed Oct 7: the highlight now outlines only the panel. Dropping anywhere on the media side, tabs included, still adds the file. Drag-and-drop still has no test, so check it by hand.
- **Oct 7 · Can't delete a PDF, image or take.** Once a file was attached to an item, there was no way to remove it.
  - Fixed Oct 7: right-click any PDF, image or take for **Open** and **Delete…**. Delete asks first, then removes Sustain's copy. The original in Finder isn't touched. A unit test covers it; the menu itself is untested, so check it by hand.
  - Items themselves: right-click a row in Library to delete one (that was already there). Today's rows have no right-click menu yet.
- **Oct 7 · No piano for vocal scales.** Warming up needs a piano that plays the scale and moves it up by half steps; Sustain had nothing for that.
  - Added Oct 7: Voice items get a **Scales** tab (it opens there when the item has no video or files). Pick a pattern (1 2 3 2 1, five-note, arpeggio, octave…), the starting notes (e.g. C3 to G3), direction and speed, then press **Play** or **Space**. Each round is the chord, then the pattern, then a breath. Hold any key on the keyboard to hear that note. Changing a setting stops playback.
  - Tests: the scale logic has unit tests; the panel renders in the screenshot test (`6-scales-*.png` in CI's "screens" artifact). The sound itself is untested, since CI has no speakers. Check by ear: it should sound like a grand piano, not a beep.
  - Open questions: should each item remember its own range and pattern? Do you want minor or other patterns, or a different chord (none, or just the root)?
- **Oct 7 · No app icon.** Sustain shows the generic icon in the Dock, so it's hard to spot. **Parked until after the M0 week.**
  - Brief for the designer: https://claude.ai/code/artifact/0301816b-c18c-4dbe-b72a-f76c6ffdaf0a. Claude's rejected sketches: `design/icon-concepts/` and the "Sustain Icon Concepts" canvas.
  - References Chris likes: Sonofield Ear Trainer and Windtone (small motif, deep tile, a little material such as glow or brass), and Teenage Engineering (warm, tactile, playful). Logic is too layered; Ableton is too simple.
  - Rejected: flat clip-art shapes; literal music objects (pedal, tuning fork, knob, note, fermata); charts (envelope, gate); anything that reads as a heartbeat, target, slider or keyhole.
  - Still open: the idea itself. Next step: ask the designer for 3 directions on "a mark that stays" or "something that keeps going", execution left to them.
