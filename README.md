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

## Install, versions and bugs

`tools/install.sh` builds the checked-out commit and installs it in /Applications. It refuses to build with uncommitted changes, so every installed build maps to a commit. The bottom of Settings shows the version, e.g. "Sustain 0.3.0 (57)", where 57 is the commit count. A build run from Xcode shows (1).

The routine:

1. Every change goes into `main` through a pull request, merged only when CI is green.
2. Install from `main` with `tools/install.sh`.
3. When a release has something new, bump `MARKETING_VERSION` in `project.yml`: the middle number for features (0.3.0 → 0.4.0), the last for fixes (0.3.0 → 0.3.1). Tag what you install: `git tag v0.3.0 && git push origin v0.3.0`.
4. Bugs go in `docs/FRICTION.md` with the version from Settings. GitHub Issues take over once other people use Sustain (M4).

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
tools/               install.sh, and generators for the test fixtures (ts-fsrs golden cases, mockup theme tokens)
```

## Tests

- **Core** (any OS with Swift 6.2): `swift test --package-path Packages/SustainCore`
- **App** (macOS): `xcodebuild test -project Sustain.xcodeproj -scheme Sustain -destination 'platform=macOS'`

CI runs both on every push: `.github/workflows/core.yml` on Linux and `app.yml` on macOS 26.
