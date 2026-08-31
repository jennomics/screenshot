// Preconditions 0.1 / 0.2: verify toolchain binaries and required env vars.
// Exits zero only when the machine can run the whole pipeline.

import { resolveEnv } from "../config.js";
import { capture, fail, log } from "../util.js";
import { gcHealth } from "../groundcrew.js";

async function haveBinary(name: string, versionArgs: string[]): Promise<boolean> {
  try {
    await capture(name, versionArgs);
    return true;
  } catch {
    return false;
  }
}

export async function checkEnv(): Promise<void> {
  const stage = "check-env";
  const problems: string[] = [];

  const bins: Array<[string, string[]]> = [
    ["xcodebuild", ["-version"]],
    ["xcodegen", ["--version"]],
    ["xcrun", ["simctl", "help"]],
    ["ffmpeg", ["-version"]],
    ["ffprobe", ["-version"]],
    ["node", ["--version"]],
  ];
  for (const [bin, args] of bins) {
    const ok = await haveBinary(bin, args);
    log(stage, `${ok ? "ok" : "MISSING"}  ${bin}`);
    if (!ok) problems.push(`missing binary: ${bin}`);
  }

  const env = resolveEnv();
  if (!env.ok) {
    for (const p of env.problems) log(stage, `MISSING  ${p}`);
    problems.push(...env.problems);
  } else {
    log(stage, `ok  ELEVENLABS_API_KEY (${env.config!.elevenLabsApiKey.length} chars)`);
    log(stage, `ok  ELEVENLABS_VOICE_ID ${env.config!.elevenLabsVoiceId}`);
    log(stage, `ok  music track -> ${env.config!.musicTrack}`);
    log(stage, `ok  music license -> ${env.config!.musicLicense ?? "(none set)"}`);
  }

  // Groundcrew execution channel: the pipeline routes shell work through it.
  const gc = await gcHealth();
  log(stage, `${gc.ok ? "ok" : "MISSING"}  groundcrew @ ${gc.base} (${gc.detail})`);
  if (!gc.ok) problems.push(`groundcrew unreachable: ${gc.detail}`);
  if (!process.env.GC_AUTH_TOKEN) problems.push("GC_AUTH_TOKEN not set (required to POST commands)");

  if (problems.length > 0) {
    fail(stage, `${problems.length} problem(s):\n  - ${problems.join("\n  - ")}`);
  }
}
