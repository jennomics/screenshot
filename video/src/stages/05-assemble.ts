// Stage 5 — assembly.
//
// 1. Concatenate the scene MP4s (assets/scenes/*.mp4) in script order into one
//    silent 1080p video.
// 2. Build the voiceover track: place each scene's VO mp3 at that scene's
//    cumulative start offset on the timeline.
// 3. Mix VO over the music bed with the music ducked ~18 dB under speech
//    (sidechain compression keyed by the VO). Loop/trim music to length.
// 4. Encode 1920x1080 H.264 30fps -> out/screenshot-demo.mp4 (A2, R11).
// 5. Copy the music license into assets/music/LICENSE.txt so provenance travels
//    with the output.
//
// ffmpeg runs locally (fast, read-only inputs, no approval friction).

import { existsSync, mkdirSync, rmSync, writeFileSync, copyFileSync } from "node:fs";
import { join } from "node:path";
import { basename } from "node:path";
import { paths, OUTPUT, resolveEnv } from "../config.js";
import { fail, log, assertArtifact, run, ffprobeDurationSec } from "../util.js";
import { loadScript, sceneDurationSec } from "../script.js";

export async function stageAssemble(): Promise<void> {
  const stage = "05";

  if (!existsSync(paths.script)) fail(stage, "script.json missing; run stage 01 first");
  const script = loadScript(paths.script);

  const env = resolveEnv();
  if (!env.ok) fail(stage, `environment not ready:\n  - ${env.problems.join("\n  - ")}`);
  const { musicTrack, musicLicense } = env.config!;

  mkdirSync(paths.out, { recursive: true });
  mkdirSync(paths.music, { recursive: true });

  // Verify every scene mp4 + vo mp3 exists, and compute cumulative offsets.
  const scenesInfo: Array<{ id: string; video: string; vo: string; startSec: number; durSec: number }> = [];
  // Lead-in: hold the voiceover back from the very first frame so the opening
  // word isn't clipped and the video has a beat of music before narration
  // begins. The video timeline still starts at 0 (scenes fade in; music opens
  // quietly); only the VO is shifted later by this much.
  const LEAD_IN_SEC = 1.0;

  let cursor = 0;
  for (const scene of script.scenes) {
    const video = join(paths.scenes, `${scene.id}.mp4`);
    const vo = join(paths.vo, `${scene.id}.mp3`);
    assertArtifact(stage, video, `scene video ${scene.id}`);
    assertArtifact(stage, vo, `vo ${scene.id}`);
    const durSec = sceneDurationSec(scene);
    // VO for this scene starts LEAD_IN_SEC after the scene's visual start.
    scenesInfo.push({ id: scene.id, video, vo, startSec: cursor + LEAD_IN_SEC, durSec });
    cursor += durSec;
  }
  const totalSec = cursor;
  log(stage, `assembling ${scenesInfo.length} scenes, ~${totalSec.toFixed(1)}s total (VO lead-in ${LEAD_IN_SEC}s)`);

  // --- 1. Concat scene videos (silent) via the concat demuxer ---
  const listPath = join(paths.assets, "concat-list.txt");
  writeFileSync(listPath, scenesInfo.map((s) => `file '${s.video}'`).join("\n") + "\n");
  const silentVideo = join(paths.assets, "_concat-video.mp4");
  rmSync(silentVideo, { force: true });
  await run(
    "ffmpeg",
    [
      "-y", "-f", "concat", "-safe", "0", "-i", listPath,
      // Re-encode on concat to normalize timestamps/gop across scenes.
      "-an",
      "-c:v", "libx264", "-preset", "medium", "-crf", "18",
      "-pix_fmt", "yuv420p", "-r", String(OUTPUT.fps),
      silentVideo,
    ],
    { quiet: true }
  );
  assertArtifact(stage, silentVideo, "concatenated video");

  // --- 2. Build the VO track: each scene's mp3 delayed to its start offset ---
  // adelay takes milliseconds per channel. Sum all delayed VO streams.
  const voInputs: string[] = [];
  const voFilters: string[] = [];
  scenesInfo.forEach((s, i) => {
    voInputs.push("-i", s.vo);
    const ms = Math.round(s.startSec * 1000);
    voFilters.push(`[${i}:a]adelay=${ms}|${ms},apad[a${i}]`);
  });
  const voMixLabels = scenesInfo.map((_, i) => `[a${i}]`).join("");
  const voConcatFilter =
    voFilters.join(";") +
    `;${voMixLabels}amix=inputs=${scenesInfo.length}:normalize=0[vomix]` +
    // trim/pad VO to total length (+lead-in headroom so a VO shifted by the
    // lead-in near the end isn't clipped)
    `;[vomix]atrim=0:${totalSec + LEAD_IN_SEC},asetpts=N/SR/TB[vo]`;

  const voTrack = join(paths.assets, "_vo.m4a");
  rmSync(voTrack, { force: true });
  await run(
    "ffmpeg",
    ["-y", ...voInputs, "-filter_complex", voConcatFilter, "-map", "[vo]", "-c:a", "aac", "-b:a", "192k", voTrack],
    { quiet: true }
  );
  assertArtifact(stage, voTrack, "voiceover track");

  // --- 3. Mix VO over music with sidechain ducking (-18 dB under speech) ---
  // Music is looped to cover the whole timeline, trimmed to length, faded out
  // at the end, then sidechain-compressed keyed by the VO so it drops ~18 dB
  // when narration is present (R10).
  //
  // Versioned output: NEVER overwrite a prior render. Each pass writes a new
  // timestamped (and optionally labeled via OUT_LABEL) file, and `latest` copies
  // point at the newest for convenience. See BACKLOG.md.
  const stamp = new Date().toISOString().replace(/[:T]/g, "-").replace(/\..+/, "");
  const label = process.env.OUT_LABEL ? `-${process.env.OUT_LABEL.replace(/[^\w.-]/g, "_")}` : "";
  const finalOut = join(paths.out, `screenshot-demo${label}-${stamp}.mp4`);
  // Do NOT rmSync — versioned filename is unique.

  // makeup/threshold tuned so ducking depth lands near -18 dB under speech.
  const mixFilter =
    // music: loop, trim, gentle bed level
    `[1:a]aloop=loop=-1:size=2e9,atrim=0:${totalSec},asetpts=N/SR/TB,volume=0.6[music];` +
    // duck music by the VO (sidechain)
    `[music][2:a]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=350:makeup=1[ducked];` +
    // mix ducked music with VO at full
    `[ducked][2:a]amix=inputs=2:normalize=0,afade=t=out:st=${(totalSec - 1.2).toFixed(2)}:d=1.2[aout]`;

  await run(
    "ffmpeg",
    [
      "-y",
      "-i", silentVideo, // 0: video
      "-i", musicTrack, // 1: music
      "-i", voTrack, // 2: VO
      "-filter_complex", mixFilter,
      "-map", "0:v", "-map", "[aout]",
      "-c:v", "libx264", "-preset", "medium", "-crf", "18", "-pix_fmt", "yuv420p",
      "-r", String(OUTPUT.fps), "-s", `${OUTPUT.width}x${OUTPUT.height}`,
      "-c:a", "aac", "-b:a", "256k",
      "-movflags", "+faststart",
      "-shortest",
      finalOut,
    ],
    { quiet: true }
  );
  assertArtifact(stage, finalOut, "final video");

  // --- 4. Copy the music track + license so the project is self-contained and
  //        provenance travels with the output ---
  const trackDest = join(paths.music, basename(musicTrack));
  copyFileSync(musicTrack, trackDest);
  log(stage, `music track -> ${trackDest} (from ${musicTrack})`);
  if (musicLicense) {
    const dest = join(paths.music, "LICENSE.txt");
    copyFileSync(musicLicense, dest);
    log(stage, `music license -> ${dest} (from ${basename(musicLicense)})`);
  } else {
    log(stage, "WARNING: no music license found (MUSIC_TRACK_LICENSE unset)");
  }

  // Clean intermediates.
  for (const f of [listPath, silentVideo, voTrack]) rmSync(f, { force: true });

  // --- Verify the result ---
  const finalDur = await ffprobeDurationSec(finalOut);

  // NOTE: we deliberately do NOT maintain a fixed `latest.mp4`. Rewriting the
  // same filename in place caused media players to serve a stale/cached handle
  // (a render would show as black/silent because the player held the previous
  // file). Each render is a uniquely-named, immutable artifact; VERSIONS.md
  // lists them newest-last, and the stage logs the exact path to open.
  const voBackend = process.env.VO_BACKEND === "say" ? "say" : "elevenlabs";
  const versionsLog = join(paths.out, "VERSIONS.md");
  const entry =
    `- \`${basename(finalOut)}\` — ${new Date().toISOString()} · ${finalDur.toFixed(1)}s · ` +
    `VO: ${voBackend}${process.env.OUT_LABEL ? ` · label: ${process.env.OUT_LABEL}` : ""}\n`;
  if (existsSync(versionsLog)) {
    const { appendFileSync } = await import("node:fs");
    appendFileSync(versionsLog, entry);
  } else {
    writeFileSync(versionsLog, `# Rendered video versions\n\n${entry}`);
  }

  log(stage, `done -> ${finalOut}  (${finalDur.toFixed(1)}s)`);
  log(stage, `open this exact file to review (no fixed latest.mp4 — avoids stale player cache)`);
  if (finalDur < 55 || finalDur > 80) {
    log(stage, `WARNING: final runtime ${finalDur.toFixed(1)}s is outside the 60-75s target`);
  }
}
