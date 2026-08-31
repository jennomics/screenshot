// Central configuration + environment resolution for the video pipeline.
//
// Credentials and machine-specific paths come from environment variables only
// (requirement N1 — nothing secret is written to disk or committed). The
// operator's ~/.zshrc exports these; run the pipeline from a login shell.

import { existsSync, statSync, readdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve, extname } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// video/ is the project root; src/ lives directly under it.
export const VIDEO_ROOT = resolve(__dirname, "..");
export const REPO_ROOT = resolve(VIDEO_ROOT, "..");

export const paths = {
  repoRoot: REPO_ROOT,
  videoRoot: VIDEO_ROOT,
  requirements: join(REPO_ROOT, "V1_REQUIREMENTS.md"),
  projectYml: join(REPO_ROOT, "project.yml"),
  uiTests: join(REPO_ROOT, "UITests"),

  assets: join(VIDEO_ROOT, "assets"),
  script: join(VIDEO_ROOT, "assets", "script.json"),
  appCapture: join(VIDEO_ROOT, "assets", "app-capture"),
  vo: join(VIDEO_ROOT, "assets", "vo"),
  scenes: join(VIDEO_ROOT, "assets", "scenes"),
  music: join(VIDEO_ROOT, "assets", "music"),
  out: join(VIDEO_ROOT, "out"),
  outFile: join(VIDEO_ROOT, "out", "screenshot-demo.mp4"),

  remotionEntry: join(VIDEO_ROOT, "src", "remotion", "index.ts"),
};

// The simulator device the pipeline creates and records on. Never an existing
// device (spec 3.3). iPhone 16 Pro per the operator's choice.
export const SIMULATOR = {
  name: "Screenshot-Demo",
  deviceType: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
  scheme: "Screenshot",
};

// Final encode target (A2).
export const OUTPUT = { width: 1920, height: 1080, fps: 30 };

export interface EnvConfig {
  elevenLabsApiKey: string;
  elevenLabsVoiceId: string;
  musicTrack: string; // resolved to a concrete file
  musicLicense: string | null;
}

interface EnvResult {
  ok: boolean;
  config?: EnvConfig;
  problems: string[];
}

// Resolve MUSIC_TRACK_PATH: it may point at a file OR a directory. When it is a
// directory we pick a track deterministically (first audio file by name) so
// adding more tracks later doesn't require code changes. A future --music flag
// can override; for now selection is filename-sorted.
function resolveMusicTrack(raw: string, problems: string[]): string | null {
  if (!existsSync(raw)) {
    problems.push(`MUSIC_TRACK_PATH does not exist: ${raw}`);
    return null;
  }
  const st = statSync(raw);
  if (st.isFile()) return raw;
  if (st.isDirectory()) {
    const audio = readdirSync(raw)
      .filter((f) => [".mp3", ".m4a", ".wav", ".aac", ".flac"].includes(extname(f).toLowerCase()))
      .sort();
    if (audio.length === 0) {
      problems.push(`MUSIC_TRACK_PATH directory has no audio files: ${raw}`);
      return null;
    }
    return join(raw, audio[0]);
  }
  problems.push(`MUSIC_TRACK_PATH is neither file nor directory: ${raw}`);
  return null;
}

export function resolveEnv(): EnvResult {
  const problems: string[] = [];
  const need = (k: string): string => {
    const v = process.env[k];
    if (!v || v.trim() === "") problems.push(`Missing env var: ${k}`);
    return v ?? "";
  };

  const elevenLabsApiKey = need("ELEVENLABS_API_KEY");
  const elevenLabsVoiceId = need("ELEVENLABS_VOICE_ID");
  const musicRaw = need("MUSIC_TRACK_PATH");

  const musicTrack = musicRaw ? resolveMusicTrack(musicRaw, problems) : null;

  // License is optional as an env var; if present and readable we carry it into
  // the video project so provenance travels with the output.
  const licenseRaw = process.env.MUSIC_TRACK_LICENSE ?? null;
  const musicLicense = licenseRaw && existsSync(licenseRaw) ? licenseRaw : null;
  if (licenseRaw && !musicLicense) {
    problems.push(`MUSIC_TRACK_LICENSE set but not found: ${licenseRaw}`);
  }

  if (problems.length > 0) return { ok: false, problems };

  return {
    ok: true,
    problems: [],
    config: {
      elevenLabsApiKey,
      elevenLabsVoiceId,
      musicTrack: musicTrack!,
      musicLicense,
    },
  };
}
