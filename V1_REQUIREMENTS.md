# Screenshot app — v1 requirements (working notes)

A lightweight, ADHD-oriented iOS app that captures the *intent* behind a
screenshot at the moment it's taken, then resurfaces it later. Standalone,
on-device, private. Design follows the partyswoop system.

## Confirmed decisions

- **Capture:** both a Share Extension (intentional in-the-moment saves) and a
  Photos-library scanner (catches forgotten screenshots).
- **Intelligence:** on-device for v1 (Vision + NaturalLanguage/OCR), with an
  optional cloud-LLM upgrade later. No screenshots leave the device in v1.
- **No Pinterest integration in v1.**
- **Reminders/nudges:** local notifications, on-device.

## Core capture flow (the modal)

Triggered from the Share Extension / Photos scan. Presents a bottom sheet:

- Screenshot preview + source.
- **Category is multi-select.** The on-device model pre-selects one suggestion
  (label reads "Suggested"). Selecting/deselecting others switches the label to
  "Purpose". Cannot deselect to zero. Example: an errand *for* the kids = both
  To-do/Errands + Kids.
- Optional free-text "why I'm saving this".
- **Two save actions, not save/don't-save:** "Save info" (extract the useful
  text, drop the image — the recommended default) vs "Save image" (keep the
  screenshot). Both commit.
- **Reminder** (optional) with an implied expiry window so time-sensitive saves
  auto-fade instead of piling up.
- Dismiss is explicit only: an X (top-right) and a quiet "Taken by mistake?
  Cancel" link. **No tap-outside-to-dismiss** (and disable swipe-to-dismiss, or
  confirm it, in SwiftUI) so nothing closes invisibly.
- After saving: brief confirmation, then auto-dismiss back to the originating
  app so flow state isn't broken.

## Due-date auto-detection (v1 — confirmed must-have)

When "Save info" extraction runs, the on-device pass also scans the extracted
text for date/deadline cues and proposes a due date.

- Use `NSDataDetector` (`.date`) and/or `DateComponentsFormatter`-style parsing
  over the OCR'd text to find absolute ("Sep 15") and relative ("within 30
  days", "closes Fri", "tomorrow") date expressions. Resolve to a concrete date.
- In the modal, if a due date is detected: show a **"Detected"** banner with the
  matched source phrase, pre-select the resolved date, and offer preset chips
  (Today / Tomorrow / In 3 days / In a week / the detected value) plus "No date".
  Zero typing required; user can accept, change, or clear.
- If nothing is detected: show an "Add a due date" affordance with the same
  presets (unselected).
- Detected due dates feed the reminder + the home "Needs attention" section.
- Confirmation flash echoes the due date.

## Home screen

Vertical order, top to bottom:

1. **Needs attention** (only if any) — items overdue or due within ~3 days,
   most-urgent first, with urgency flags (Overdue / Due today / Due soon).
   Sits above everything on a live-wash background.
2. **Most recent** — a *compact* horizontal marquee (small swatch + 2-line
   summary, ~76px tall), items interleaved across categories by recency. Kept
   deliberately short so the first time-bucket peeks above the fold.
3. **Looking back** — time-bucket cards: Yesterday → This week → Last week →
   This month → Last month → This quarter → Last quarter → This year → Last
   year. Each bucket shows only content NOT already surfaced by a more-recent
   bucket. **Empty buckets do not render.** Each card is its own swap (cross-
   fade) carousel rotating through that bucket's items.

Both carousels **auto-advance**; tapping the arrows (or dots) **permanently
stops** that carousel's auto-advance for the session.

## Resurfacing nudges (ADHD-oriented)

Gentle, specific, memory-jogging prompts, e.g. "Last week you explored painting
inspiration", "Yesterday you were figuring out driver's ed", "Last month 80% of
your shopping screenshots were kitten heels". Delivered on home + via local
notifications.

## Collections review

Pinterest-style masonry grid, filterable by category. Collection detail shows
saved images and "info kept" cards distinctly. Faded/expired items move to a
recoverable archive — never hard-deleted.

## iOS platform constraints (known, accepted)

- Cannot suppress/replace the system screenshot preview (Markup/Share/etc.).
- Cannot auto-launch the app or draw a modal over other apps from the
  background. Hence the Share-Extension + Photos-scan approach rather than an
  invisible interceptor.

## Prototype

Clickable web prototype of these flows lives in `prototype/`
(`python3 -m http.server` from that dir). It's a UX reference for the SwiftUI
build; categories/suggestions/extraction/dates are seeded, not real inference.
