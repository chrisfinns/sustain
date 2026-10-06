# Sustain

A spaced-repetition practice app for musicians: "Anki for any instrument". A native macOS app (SwiftUI, macOS 26). Everything stays on your Mac.

- Product rules: `docs/PLAN.md`
- Build plan and milestones: `docs/SWIFT_PLAN.md`
- Approved UI: `design/mockup/` (canvas: https://claude.ai/artifact/TSe1AHctNW6q3tCF7dqDYC)

## Run it on your Mac

You need Xcode 26 and Homebrew. No Apple Developer account is needed; the app is signed to run locally.

```sh
brew install xcodegen
xcodegen generate        # creates Sustain.xcodeproj from project.yml (not committed)
open Sustain.xcodeproj   # then press ⌘R
```

Run `xcodegen generate` again after pulling changes that add or move files.

### YouTube test (M0 step 1)

In the running app: **Debug › YouTube Test…**. Paste a lesson video link and press Load, then:

1. Press **Play**. The first check turns green when the video plays.
2. Press **Test 50–100 %** to see which speeds YouTube honors.
3. Press **Set A here** and **Set B here** a few seconds apart, turn **Loop** on, and let it wrap at least 3 times.

Then press **Copy report** and paste the result back into the Claude session.

## Layout

```
App/                 the macOS app (SwiftUI views, SwiftData store)
AppTests/            unit tests against an in-memory store
AppUITests/          end-to-end keyboard flows (Capture, rating, areas)
Packages/SustainCore Foundation-only rules: FSRS scheduler, Today queue, areas, theme, links, backup format
tools/               generators for the test fixtures (ts-fsrs golden cases, mockup theme tokens)
```

## Tests

- **Core** (any OS with Swift 6.2): `swift test --package-path Packages/SustainCore`
- **App** (macOS): `xcodebuild test -project Sustain.xcodeproj -scheme Sustain -destination 'platform=macOS'`

CI runs both on every push: `.github/workflows/core.yml` on Linux and `app.yml` on macOS 26.
