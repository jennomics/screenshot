# Video pipeline — backlog

Deferred items and known follow-ups for the marketing-video pipeline.

## Artifact versioning (requested)

**Directive:** When the user asks for changes, do NOT overwrite the previous
output. Preserve every reviewed iteration so versions can be compared.

- [ ] Bake versioning into stage 5: write each render to a timestamped/labeled
      file (e.g. `out/screenshot-demo-<label>-YYYYMMDD-HHMMSS.mp4`) instead of a
      fixed `screenshot-demo.mp4`, and update a `latest` symlink/pointer.
- [ ] Maintain `out/VERSIONS.md` describing each artifact (VO backend, date,
      what changed) so drafts are easy to tell apart.
- [ ] Consider versioning reviewed intermediate artifacts too (e.g. `assets/vo/`
      variants) rather than regenerating in place, when a change would clobber a
      version the user might want side-by-side.

Interim practice until baked in: manually write new passes to a new filename and
never overwrite an existing reviewed `out/*.mp4`.

## Product design — capture flow (not just video)

- [ ] Consider splitting the capture modal into a short multi-screen flow:
      (1) captured screenshot + extracted detail for review + Save info / Save
      image, (2) categorize, (3) assign due date. Rationale: in one dense sheet
      the two primary "Save info / Save image" actions sit at the bottom and
      don't draw the eye (surfaced while reviewing the marketing video). A
      stepped flow would foreground each decision. This is a real UX decision
      about the app, separate from the video — decide deliberately. For the
      video we currently direct attention with a zoom/pan instead.

## Other follow-ups

- [ ] Restore ElevenLabs as the sole VO path once plan access is confirmed
      stable (currently works; `say` fallback retained behind `VO_BACKEND`).
- [ ] Stage 2 capture is heavy (~6-7 min/flow, load spikes). Explore booting the
      sim once and reusing across flows without per-flow erase, or lighter reset.
- [ ] App-window trim detection is heuristic (paper-color classifier). Consider a
      more robust signal (e.g. a hidden UITest marker frame) if it ever misfires.
