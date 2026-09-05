// Stage 3 — voiceover.
//
// One ElevenLabs synthesis request per scene -> assets/vo/{id}.mp3. Then ffprobe
// each clip and write `actualVoSec` back into assets/script.json so stage 4 can
// extend scene durations to fit the narration (R9). Credentials come from env
// only (N1).

import { writeFileSync, mkdirSync, existsSync, rmSync } from "node:fs";
import { join } from "node:path";
import { paths, resolveEnv } from "../config.js";
import { fail, log, assertArtifact, ffprobeDurationSec, run } from "../util.js";
import { loadScript, saveScript, type Scene } from "../script.js";

// Voiceover backend. Default is ElevenLabs (R8). `say` is a zero-cost local
// fallback (macOS system TTS) for producing a first-pass draft when the
// ElevenLabs account lacks API voice access; swap back by unsetting VO_BACKEND.
type VoBackend = "elevenlabs" | "say";
const VO_BACKEND: VoBackend = (process.env.VO_BACKEND as VoBackend) || "elevenlabs";
const SAY_VOICE = process.env.SAY_VOICE || "Samantha";
const SAY_WPM = process.env.SAY_WPM || "170"; // slightly measured for a VO read

const ELEVEN_BASE = "https://api.elevenlabs.io/v1/text-to-speech";

// eleven_multilingual_v2 is the stable, high-quality default. mp3_44100_128 is
// a clean 44.1kHz/128kbps MP3 that ffmpeg mixes without resampling surprises.
const MODEL_ID = "eleven_multilingual_v2";
const OUTPUT_FORMAT = "mp3_44100_128";

async function synthesize(
  apiKey: string,
  voiceId: string,
  text: string
): Promise<Buffer> {
  const res = await fetch(`${ELEVEN_BASE}/${voiceId}?output_format=${OUTPUT_FORMAT}`, {
    method: "POST",
    headers: {
      "xi-api-key": apiKey,
      "Content-Type": "application/json",
      Accept: "audio/mpeg",
    },
    body: JSON.stringify({
      text,
      model_id: MODEL_ID,
      // Calm, steady read for a marketing VO: high stability, moderate
      // similarity, a little style, speaker boost on.
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.75,
        style: 0.15,
        use_speaker_boost: true,
      },
    }),
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => "");
    // Never echo the API key; only the status + provider message.
    fail("03", `ElevenLabs request failed (HTTP ${res.status}): ${detail.slice(0, 500)}`);
  }
  const arrayBuf = await res.arrayBuffer();
  return Buffer.from(arrayBuf);
}

// macOS `say` -> AIFF, then ffmpeg -> MP3 (44.1k/128k to match the ElevenLabs
// path so stage 5's mix behaves identically regardless of backend).
async function synthesizeSay(text: string, mp3Path: string): Promise<void> {
  const aiff = mp3Path.replace(/\.mp3$/, ".aiff");
  await run("say", ["-v", SAY_VOICE, "-r", SAY_WPM, "-o", aiff, text], { quiet: true });
  await run(
    "ffmpeg",
    ["-y", "-i", aiff, "-codec:a", "libmp3lame", "-b:a", "128k", "-ar", "44100", mp3Path],
    { quiet: true }
  );
  rmSync(aiff, { force: true });
}

// Produce assets/vo/{id}.mp3 for one scene via the selected backend.
async function synthesizeScene(
  scene: Scene,
  mp3Path: string,
  creds: { apiKey: string; voiceId: string }
): Promise<void> {
  if (VO_BACKEND === "say") {
    await synthesizeSay(scene.vo, mp3Path);
    return;
  }
  const audio = await synthesize(creds.apiKey, creds.voiceId, scene.vo);
  if (audio.length === 0) fail("03", `empty audio returned for scene ${scene.id}`);
  writeFileSync(mp3Path, audio);
}

export async function stageVoice(): Promise<void> {
  const stage = "03";

  // Only ElevenLabs needs credentials; `say` runs locally.
  let creds = { apiKey: "", voiceId: "" };
  if (VO_BACKEND === "elevenlabs") {
    const env = resolveEnv();
    if (!env.ok) fail(stage, `environment not ready:\n  - ${env.problems.join("\n  - ")}`);
    creds = { apiKey: env.config!.elevenLabsApiKey, voiceId: env.config!.elevenLabsVoiceId };
  }
  log(stage, `voiceover backend: ${VO_BACKEND}${VO_BACKEND === "say" ? ` (voice ${SAY_VOICE})` : ""}`);

  if (!existsSync(paths.script)) fail(stage, `script.json missing; run stage 01 first`);
  const script = loadScript(paths.script);

  mkdirSync(paths.vo, { recursive: true });

  for (const scene of script.scenes) {
    const mp3 = join(paths.vo, `${scene.id}.mp3`);
    log(stage, `synthesizing "${scene.id}" (${scene.vo.length} chars)`);

    await synthesizeScene(scene, mp3, creds);
    assertArtifact(stage, mp3, `vo clip ${scene.id}`);

    const dur = await ffprobeDurationSec(mp3);
    scene.actualVoSec = Math.round(dur * 1000) / 1000;
    log(stage, `  -> ${scene.id}.mp3  ${scene.actualVoSec}s`);
  }

  // Persist actualVoSec back into the cached script (re-validates on save).
  saveScript(paths.script, script);

  const total = script.scenes.reduce((s, sc) => s + (sc.actualVoSec ?? 0), 0);
  log(stage, `voiceover complete: ${script.scenes.length} clips, ${Math.round(total)}s total narration`);
}
