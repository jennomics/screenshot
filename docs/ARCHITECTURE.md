# Architecture — Screenshot app

Standalone, on-device, private iOS app. Three code units:

```
┌─────────────────┐     ┌──────────────────┐
│  Screenshot     │     │  ShareExtension  │
│  (SwiftUI app)  │     │  (capture modal) │
└────────┬────────┘     └────────┬─────────┘
         │  both import + link    │
         └──────────┬─────────────┘
                    ▼
          ┌───────────────────┐
          │   ScreenshotKit   │  (Swift package)
          │  models + logic   │
          │  + design system  │
          └─────────┬─────────┘
                    ▼
     App Group container (shared filesystem)
          Screenshot.store  (SwiftData / SQLite)
```

- **Screenshot** — the app you open to browse. Reads the shared store.
- **ShareExtension** — a separate process. Presents the capture modal when you
  tap Share → this app on the screenshot preview, writes to the shared store,
  then dismisses back to the originating app.
- **ScreenshotKit** — the "shared on-device data layer". SwiftData models, the
  `ModelContainer` pointed at the App Group container, domain logic (time
  bucketing, due status), and the partyswoop design system. Imported by both
  targets so they share one schema and one database file.

## Why the shared data layer exists

An iOS app extension runs in its own sandbox, isolated from the main app. An
**App Group** grants both a shared container (a folder both can read/write). We
place the SwiftData store file inside that container, so the extension's saves
are immediately visible to the app and vice versa. Nothing leaves the device;
there is no server and no cloud in v1.

Configuration touchpoints (all use the same group id):
- `ScreenshotKit/.../Store/DataStore.swift` → `appGroupID`
- `App/Screenshot.entitlements`
- `ShareExtension/ShareExtension.entitlements`

## Capture paths (both write to the same store)

1. **Share Extension** — intentional, in-the-moment. `ShareViewController` loads
   the shared image and hosts `CaptureModalView`, which runs on-device analysis
   (categories + OCR + due-date detection), then writes a `SavedItem`.
2. **Photos scanner** (`ScreenshotKit/.../Photos/PhotoScanner.swift`) — scans the
   camera roll for screenshots (`PHAssetMediaSubtype.photoScreenshot`), skips any
   already imported (dedupe by `SavedItem.sourceAssetID`), OCRs + analyzes each
   new one, and files it as an `.info` item. Triggered from the Tools sheet
   ("Scan screenshots now"). Requires `NSPhotoLibraryUsageDescription`.

## Reminders / notifications

`ScreenshotKit/.../Notifications/NotificationScheduler.swift` schedules local
`UNNotificationRequest`s from a `SavedItem`'s due date / `ReminderPlan` (fires
at the reminder time, or 9am on the due day). Authorization is requested once at
app launch. Local only — no push server. When an item is archived/completed,
`cancel(for:)` removes the pending request.

## On-device intelligence (v1)

- **Categorization** — Vision image classification + heuristics over OCR text.
- **Extraction** ("Save info") — VisionKit/Vision OCR to pull the useful text.
- **Due-date detection** — `NSDataDetector(.date)` plus light relative-phrase
  parsing ("closes Fri", "within 30 days") over the OCR text. Confirmed v1
  must-have. Surfaces as the pre-filled due chip in the capture modal and feeds
  the home "Needs attention" section + local-notification reminders.

Optional cloud-LLM upgrade is a later enhancement; v1 keeps everything local.
