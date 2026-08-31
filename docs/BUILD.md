# Build & setup

## Prerequisites

- **Xcode 15+** (for the `@Model` SwiftData macro and iOS 17 SDK).
- **XcodeGen** to generate the `.xcodeproj` from `project.yml`:
  ```
  brew install xcodegen
  ```

This machine currently has the standalone Command Line Tools selected, which
lack the SwiftData macro plugin and `xcodebuild`. Point the toolchain at the
installed Xcode before building the app:

```
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

(The shared package's pure logic still builds/tests under the CLT via
`swift test` in `ScreenshotKit/`, minus the `@Model` types.)

## Generate and open the project

```
cd /Users/jennalang/kiro/screenshot
xcodegen generate
open Screenshot.xcodeproj
```

## Signing / App Group

### The App Group id lives in three places (keep them identical)

Default placeholder: `group.com.yourteam.screenshot`.

1. `ScreenshotKit/Sources/ScreenshotKit/Store/DataStore.swift` → `appGroupID`
2. `App/Screenshot.entitlements`
3. `ShareExtension/ShareExtension.entitlements`

Set the Development Team once in `project.yml` (`settings.base.DEVELOPMENT_TEAM`)
so both targets inherit it, then regenerate.

### Interim mode — free / Personal Team, or paid account pending

App Groups can't be provisioned without an active **paid** Developer account.
Until yours activates, build without the App Groups capability:

- In Xcode, for BOTH targets → Signing & Capabilities: enable **Automatically
  manage signing**, pick your (Personal) Team, and **remove the App Groups
  capability** (click the ✕ on the App Groups section) if signing complains.
- Everything still runs on the simulator and your own device. The store layer
  automatically falls back to a **local persistent store** (data persists across
  launches; see `DataStore.resolvedContainer()`), so you can develop and click
  through the app normally. The only limitation: the app and the Share Extension
  each use their own sandbox store, so they won't see each other's saves yet.

### Activated mode — once the paid account is live

For BOTH the `Screenshot` and `ShareExtension` targets, Signing & Capabilities:
- Confirm your Team is selected.
- Click **+ Capability** → **App Groups**, and add the same group id used in the
  entitlements files (ticked on both targets).

No code change is needed — `DataStore.resolvedContainer()` prefers the shared
App Group store automatically as soon as it's provisioned.

## Run

- Select the `Screenshot` scheme → run on a simulator or device.
- To test capture: take/save any image, tap **Share**, choose **Save to
  Screenshot** → the capture modal appears; saving writes to the shared store
  and the item shows up on the app's Home screen.

## Fonts

The design system references **Zen Kaku Gothic New** and **DM Mono**. Add the
font files to the app target and list them under `UIAppFonts` in `App/Info.plist`
to match the partyswoop look exactly; until then SwiftUI falls back to the
system font.

## Tests

```
cd ScreenshotKit && swift test
```

Covers time bucketing (empty-bucket drop + dedupe) and due-status logic.
