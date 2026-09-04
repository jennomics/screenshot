# Screenshot

A lightweight, ADHD-oriented iOS app that captures the *intent* behind a
screenshot at the moment you take it, then gently resurfaces it later.
Standalone, on-device, private. Design follows the partyswoop editorial system
(warm paper ground, terracotta accent, sharp corners).

The guiding idea: this is **not** another reminder app. It should be delightful
first — a calm highlight reel of things you saved — and if it happens to remind
you of something time-sensitive, that's a quiet bonus, not a wall of red.

## What it does

### Capture (the moment you save)
A bottom-sheet capture modal (from the Share Extension or the Photos scanner):

- **Screenshot preview + source.**
- **Multi-select categories.** The on-device model pre-selects one suggestion
  (label reads "Suggested"); selecting others flips the label to "Purpose" — an
  errand *for the kids* can be both To-do and Kids. You can't deselect to zero.
- **Keep the image, or just the info.** Two commit actions: "Save info"
  (extract the useful text) and "Save image" (keep the screenshot). Some saves
  are image-only (the colors in a painting), some info-only, some both.
- **Auto-detected due dates.** When text is extracted, an on-device pass scans
  for date/deadline cues (`NSDataDetector` + heuristics). If found, a
  **"Detected"** banner shows the matched phrase and offers preset chips
  (Today / Tomorrow / In 3 days / In a week / the detected value / No date).
- Explicit dismiss only (an X and a quiet "Taken by mistake? Cancel").

### Home (delight-first)
Top to bottom:

1. **Most recent** — a horizontal auto-advancing carousel, interleaved across
   categories so it doesn't clump. Manual advance stops the auto-slide for the
   session.
2. **Due over / Due soon** — two small solid-fill summary cards (terracotta /
   ink) over a pale wash. Deliberately heading-less and compact — a nudge, not
   a dashboard. Only shown when something is actually due.
3. **Looking back** — time-bucket cards (Last week / Last month / Last quarter
   / Last year) whose whole box slides through its items and pauses, like a
   quiet vertical marquee. Image saves show their thumbnail. Every saved item
   lands in exactly one bucket; empty buckets don't render.

### Collections
A Pinterest-style masonry grid, filterable by category. A collection's detail
shows saved images and "info kept" cards distinctly; faded/expired items move to
a recoverable archive (never hard-deleted).

### Resurfacing
Gentle, specific memory-jogging prompts on Home and via local notifications.
Due dates feed the reminders and the Home "due" summary.

## Architecture

- **App** (`App/`) — the SwiftUI app: Home, Collections, Settings, app entry.
- **ScreenshotKit** (`ScreenshotKit/`) — shared SwiftPM package (data model +
  SwiftData store, on-device analysis, design system/theme, the capture modal,
  time-bucketing, due-status logic). Linked into both the app and the Share
  Extension so they share one schema and store.
- **ShareExtension** (`ShareExtension/`) — the in-the-moment capture entry via
  the iOS share sheet.
- **UITests** (`UITests/`) — XCUITest demo flows used by the marketing-video
  pipeline (see below).

The project is generated with XcodeGen from `project.yml` (the source of truth;
`Screenshot.xcodeproj/` is generated and gitignored).

```bash
brew install xcodegen
xcodegen generate
open Screenshot.xcodeproj
```

Requires Xcode 15+ (developed against Xcode 26). Simulator builds need no
signing. On-device analysis uses Vision + NaturalLanguage; sample data is
DEBUG-only (`SampleData`), never compiled into release.

## Marketing video pipeline

`video/` holds a one-command pipeline that renders a ~75s marketing video:
authored script → simulator capture (XCUITest) → voiceover (ElevenLabs) →
Remotion scenes → ffmpeg assembly. See `video/` for details. It does not modify
app source beyond the DEBUG-only UITest seeding hook.

## Notes

- Product/UX facts trace to `V1_REQUIREMENTS.md` and `docs/`.
- On-device only; no screenshots leave the device in v1.
