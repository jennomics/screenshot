// Detect the app-footage window inside a raw capture .mov.
//
// The simulator recording spans the whole test: a long boot/install/launch
// stretch (black), the actual app UI (warm "paper" background, #F6F5F1), then
// teardown back to the iOS home screen (blue/gray wallpaper). We want only the
// app-UI stretch. Sample one frame per second scaled to 1x1, classify each
// second as "app" (light + warm) vs not, and take the longest contiguous run.

import { spawn } from "node:child_process";

interface AppWindow {
  startSec: number;
  endSec: number;
}

function sampleRgbPerSecond(movPath: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const args = [
      "-i", movPath,
      "-vf", "fps=1,scale=1:1",
      "-f", "rawvideo",
      "-pix_fmt", "rgb24",
      "pipe:1",
    ];
    const ff = spawn("ffmpeg", args, { stdio: ["ignore", "pipe", "ignore"] });
    const chunks: Buffer[] = [];
    ff.stdout.on("data", (d) => chunks.push(d));
    ff.on("error", reject);
    ff.on("close", (code) => {
      if (code === 0) resolve(Buffer.concat(chunks));
      else reject(new Error(`ffmpeg sampling exited ${code} for ${movPath}`));
    });
  });
}

// A second is "app UI" when the averaged pixel is the app's warm paper ground
// (#F6F5F1 with terracotta content mixed in -> ~ (228,220,212)): light, but
// warm-neutral, and crucially NOT pure white. The app shows a pure-white splash
// while launching before content loads; excluding near-white avoids trimming
// into that blank frame. Blue iOS wallpaper (b > r) and black boot screens are
// also excluded.
function isAppPixel(r: number, g: number, b: number): boolean {
  const avg = (r + g + b) / 3;
  const warm = r >= g && g >= b && r - b >= 6; // warm bias of the paper ground
  const light = avg >= 200 && avg <= 246; // light but not pure-white splash
  const notBlue = b <= r; // wallpaper is bluish
  return light && warm && notBlue;
}

export async function detectAppWindow(movPath: string): Promise<AppWindow> {
  const data = await sampleRgbPerSecond(movPath);
  const secs = Math.floor(data.length / 3);

  const runs: AppWindow[] = [];
  let start: number | null = null;
  for (let s = 0; s < secs; s++) {
    const r = data[s * 3], g = data[s * 3 + 1], b = data[s * 3 + 2];
    const app = isAppPixel(r, g, b);
    if (app && start === null) start = s;
    if (!app && start !== null) {
      runs.push({ startSec: start, endSec: s - 1 });
      start = null;
    }
  }
  if (start !== null) runs.push({ startSec: start, endSec: secs - 1 });

  if (runs.length === 0) {
    // Fallback: use the last third of the clip rather than fail — better to
    // show something than nothing for a first pass.
    return { startSec: Math.floor((secs * 2) / 3), endSec: secs - 1 };
  }

  runs.sort((a, b) => b.endSec - b.startSec - (a.endSec - a.startSec));
  const best = runs[0];
  // Trim 1s off each edge to avoid transition frames bleeding in.
  return {
    startSec: Math.min(best.startSec + 1, best.endSec),
    endSec: Math.max(best.endSec - 1, best.startSec + 1),
  };
}
