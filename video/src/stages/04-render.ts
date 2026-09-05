// Stage 4 — Remotion render.
//
// Bundles the Remotion project, stages the fonts + trimmed app clips into the
// bundle's public/ dir (so staticFile resolves them), then renders each scene
// to assets/scenes/{id}.mp4. Scene duration = max(durationSec, actualVoSec+0.5)
// (R9). App scenes embed the real captured .mov, trimmed to its detected app-UI
// window so the phone frame shows the interaction, not boot/teardown.

import { mkdirSync, existsSync, rmSync, cpSync, copyFileSync } from "node:fs";
import { join } from "node:path";
import { bundle } from "@remotion/bundler";
import { selectComposition, renderMedia } from "@remotion/renderer";
import { paths, OUTPUT } from "../config.js";
import { fail, log, assertArtifact } from "../util.js";
import { loadScript, sceneDurationSec } from "../script.js";
import { detectAppWindow } from "../appwindow.js";

// Shape of the input props the Remotion "Scene" composition expects. Kept local
// so this node-side module doesn't import the browser-side Remotion bundle.
interface FocusKeyframe { atSec: number; scale: number; panY: number }
interface SceneInput {
  type: "problem" | "solution" | "app" | "close";
  onScreenText: string;
  clipSrc?: string;
  trimStartSec?: number;
  focus?: FocusKeyframe[];
  noFadeIn?: boolean;
  noFadeOut?: boolean;
  durationInFrames: number;
}

// VO-timed camera moves for the two capture scenes. Times are scene-seconds
// (VO plays after the 1.0s lead-in, so a phrase at VO t=T lands at ~T+1.0s).
// panY: negative reveals upper part of the phone, positive lower.
//   categories: "it's an errand" ~VO 5.7s -> ~6.7s. Zoom to 1.25 centered on
//               the category chips (upper-middle), settled by ~6.7s; hold.
//   duedate:    opens already at 1.25 (continuous from categories, no fade);
//               "if there's a date" is the opening line (~1.0s) -> settle on
//               the DETECTED banner (lower-middle) almost immediately.
const CAPTURE_FOCUS: Record<string, { focus: FocusKeyframe[]; noFadeIn?: boolean; noFadeOut?: boolean }> = {
  // Single continuous capture shot. Transform is scale() then translateY():
  // POSITIVE panY reveals the phone's UPPER half, NEGATIVE reveals the LOWER
  // half. The capture modal is a bottom sheet filling the phone, so:
  //   - "top half of the sheet" (category chips) => zoom ~2x + POSITIVE panY
  //   - "bottom half" (Detected banner)          => same zoom + NEGATIVE panY
  // Timing (VO measured; +1.0s lead-in): "it's an errand" ~VO 6.0s -> ~7.0s
  // scene; "if there's a date" ~VO 9.5s -> ~10.5s scene.
  "app-capture": {
    focus: [
      { atSec: 0.0, scale: 1.9, panY: 40 },    // open on the categories, chips centered
      { atSec: 9.0, scale: 1.9, panY: 40 },    // hold on chips through "it's an errand… for your daughter"
      { atSec: 12.8, scale: 1.9, panY: -175 }, // pan DOWN during the ~3s pause, settling on DETECTED
      { atSec: 22.0, scale: 1.9, panY: -175 }, // as "if there's a date" lands (~13.3s), then hold
    ],
  },
};

export async function stageRender(): Promise<void> {
  const stage = "04";

  if (!existsSync(paths.script)) fail(stage, "script.json missing; run stage 01 first");
  const script = loadScript(paths.script);

  if (existsSync(paths.scenes)) rmSync(paths.scenes, { recursive: true, force: true });
  mkdirSync(paths.scenes, { recursive: true });

  // Public dir for the bundle: fonts + app clips referenced via staticFile.
  const publicDir = join(paths.videoRoot, "src", "remotion", "public");
  rmSync(publicDir, { recursive: true, force: true });
  mkdirSync(join(publicDir, "fonts"), { recursive: true });
  mkdirSync(join(publicDir, "clips"), { recursive: true });

  // Stage fonts from the app target.
  const fontDir = join(paths.repoRoot, "App", "Fonts");
  for (const f of [
    "ZenKakuGothicNew-Regular.ttf",
    "ZenKakuGothicNew-Medium.ttf",
    "ZenKakuGothicNew-Bold.ttf",
    "ZenKakuGothicNew-Black.ttf",
    "DMMono-Regular.ttf",
    "DMMono-Medium.ttf",
  ]) {
    const src = join(fontDir, f);
    if (existsSync(src)) copyFileSync(src, join(publicDir, "fonts", f));
    else log(stage, `WARNING: font missing ${src} (scene will fall back to system font)`);
  }

  // Stage + trim-detect app clips. Copy each flow's .mov into public/clips and
  // detect its app-UI window so AppScene can start there.
  const appTrim = new Map<number, number>(); // captureFlow -> trimStartSec

  // Manual per-flow trim overrides (seconds), for flows where the color-based
  // app-window detector can't find the right shot. The Collections masonry grid
  // is full of colorful image tiles (not the app's warm "paper" ground), so the
  // detector would otherwise land on the collection *detail* view. Point the
  // collections scene at the grid explicitly. Env TRIM_OVERRIDE_<flow> wins.
  // Manual per-flow trim (seconds). The Collections masonry grid is full of
  // colorful tiles (not the app's warm "paper" ground), so auto-detection lands
  // on the collection *detail* instead. Point clip 5 at the grid so it appears
  // early and lingers, then naturally flows into the detail view. Measured in
  // the current capture: grid ~86-89s, detail 90s+. Env TRIM_OVERRIDE_5 wins.
  // Manual trim overrides per flow (empty = auto-detect). The collections grid
  // isn't paper-colored so auto-detect can land on the detail view; set a
  // collections override below after measuring the fresh clip if needed.
  const TRIM_OVERRIDES: Record<number, number> = {
    // clip 1 (capture): start where the modal is fully settled (~88s) so the
    // 21s scene plays the modal from the top — the focus keyframes pan from the
    // category chips down to DETECTED over the scene. Auto-detect would clamp to
    // the window's END (missing the categories part), so pin the start here.
    1: 88,
    // clip 4 (collections): app launches ~83s; the masonry GRID is on screen
    // ~103-113s (auto-detect lands on the paper detail view instead). Point the
    // scene at the grid so it appears and lingers.
    4: 103,
  };

  // Cache scene durations per flow so trimStart can be clamped to fit the window.
  const flowSceneDur = new Map<number, number>();
  for (const scene of script.scenes) {
    if (scene.type === "app") flowSceneDur.set(scene.captureFlow!, sceneDurationSec(scene));
  }
  for (const scene of script.scenes) {
    if (scene.type !== "app") continue;
    const flow = scene.captureFlow!;
    const src = join(paths.appCapture, `${flow}.mov`);
    assertArtifact(stage, src, `capture clip ${flow}`);
    copyFileSync(src, join(publicDir, "clips", `${flow}.mov`));

    // Manual override (env or table) short-circuits detection.
    const envOverride = process.env[`TRIM_OVERRIDE_${flow}`];
    const override = envOverride !== undefined ? parseFloat(envOverride) : TRIM_OVERRIDES[flow];
    if (override !== undefined && isFinite(override)) {
      log(stage, `  clip ${flow}: manual trim override -> trimStart ${override}s`);
      appTrim.set(flow, override);
      continue;
    }

    log(stage, `detecting app window in clip ${flow}...`);
    const win = await detectAppWindow(src);
    // Clamp trimStart so the whole scene plays WITHIN the app window and never
    // runs past windowEnd into a transition/teardown/frozen-last-frame. If the
    // window is shorter than the scene, start as early as the window allows
    // (windowStart) and accept the shortfall rather than overrun into teardown.
    const sceneDur = flowSceneDur.get(flow) ?? 8;
    const windowLen = win.endSec - win.startSec;
    let trimStart: number;
    if (windowLen >= sceneDur) {
      // Center-ish: start so the scene ends at windowEnd (shows the settled UI).
      trimStart = Math.max(win.startSec, win.endSec - sceneDur);
    } else {
      // Window too short; start at windowStart (best available).
      trimStart = win.startSec;
    }
    log(stage, `  clip ${flow}: app window ${win.startSec}-${win.endSec}s (len ${windowLen}s) -> trimStart ${trimStart}s`);
    appTrim.set(flow, trimStart);
  }

  log(stage, "bundling Remotion project...");
  const serveUrl = await bundle({
    entryPoint: paths.remotionEntry,
    publicDir,
    onProgress: () => {},
  });

  for (const scene of script.scenes) {
    const durSec = sceneDurationSec(scene);
    const durationInFrames = Math.round(durSec * OUTPUT.fps);

    const inputProps: SceneInput = {
      type: scene.type,
      onScreenText: scene.onScreenText,
      durationInFrames,
      ...(scene.type === "app"
        ? {
            clipSrc: `clips/${scene.captureFlow}.mov`,
            trimStartSec: appTrim.get(scene.captureFlow!) ?? 0,
            ...(CAPTURE_FOCUS[scene.id] ?? {}),
          }
        : {}),
    };

    const composition = await selectComposition({
      serveUrl,
      id: "Scene",
      inputProps,
      // @ts-expect-error publicDir is accepted at runtime for asset serving
      publicDir,
    });

    const outPath = join(paths.scenes, `${scene.id}.mp4`);
    log(stage, `rendering "${scene.id}" (${scene.type}, ${durSec.toFixed(1)}s / ${durationInFrames}f)`);
    await renderMedia({
      composition,
      serveUrl,
      codec: "h264",
      outputLocation: outPath,
      inputProps,
      chromiumOptions: { gl: "angle" },
      // @ts-expect-error publicDir is accepted at runtime for asset serving
      publicDir,
    });
    assertArtifact(stage, outPath, `scene ${scene.id}`);
  }

  log(stage, `rendered ${script.scenes.length} scenes -> ${paths.scenes}`);
}
