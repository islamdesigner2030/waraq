# Waraq (ورق) — notes for Claude

Native iPhone-only Bullet Journal app (Swift 5 mode, SwiftUI + UIKit + Metal + PencilKit), iOS 26 minimum,
no external dependencies. The project is described by XcodeGen `project.yml`; `Waraq.xcodeproj` is generated, not committed.

The whole app was written on a Windows machine and has **never been compiled**. Expect a few compile errors on the first build.
The user writes in Arabic; reply in Arabic.

## Building on the Mac

1. Xcode 26 must be installed (from the App Store) and opened once to accept the licence.
2. Install XcodeGen if missing: `brew install xcodegen`.
3. If this folder lives inside OneDrive, copy it to a local folder first (for example `~/Developer/Waraq`) so sync doesn't fight build files.
4. `xcodegen generate`
5. Compile check: `xcodebuild -project Waraq.xcodeproj -scheme Waraq -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
6. Fix every error, rebuild until clean, then run in a simulator and check: language screen, create notebook, writing, each toolbar template, page curl in both directions (create one Arabic and one English notebook), save → relaunch → content and last page restored.
7. For the user's iPhone: the user chooses their own Team in Signing & Capabilities (their Apple ID — never enter credentials for them).

## Without a Mac

No Mac that runs Xcode 26 is available. `.github/workflows/ios-build.yml` builds on a GitHub macOS
runner: simulator compile, unsigned IPA, then `WaraqUITests` (XCUITest) walks every screen in English and Arabic and
`scripts/export_screenshots.py` exports the screenshots as the `screenshots` artifact. Debug-only launch environment
switches used by the tests: `WARAQ_RESET=1` (clean install, in `AppModel.init`) and `WARAQ_FREEZE_CURL=1`
(hold a page mid-curl on release, in `ReaderViewController.release`).

## Owner rules

- Priorities: extreme simplicity, realistic page turning, a well-made Bullet Journal. No extra screens or features.
- Fully offline: no accounts, servers, analytics, tracking or unneeded permissions.
- Abstract, premium visuals only — no code-drawn cartoon people.
