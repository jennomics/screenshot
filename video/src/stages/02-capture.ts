// Stage 2 — simulator capture.
//
// Records the five R6 demo flows from a dedicated simulator as .mov files.
// Sequence:
//   1. xcodegen generate
//   2. resolve/create the dedicated Screenshot-Demo device (never an existing one)
//   3. boot it ONCE, wait for full boot, let the first-boot daemon storm settle
//   4. xcodebuild build-for-testing (once)
//   5. per flow: erase-in-place for identical state (R7), start recordVideo,
//      run the single XCUITest method, stop recording, validate the .mov
//
// Hard-won constraints from earlier runs:
// - Every sim/build command runs with retries: 0. groundcrew's default retry
//   re-runs the WHOLE command on failure; for a sim boot that means a second
//   boot storm, which spikes system load. Never retry these.
// - Boot the sim once and erase between flows rather than shutdown+boot per
//   flow — each cold boot triggers ~180 simulator daemons. Erase-in-place on an
//   already-booted device is far cheaper and still gives identical state.
// - A load guard refuses to start if the machine is already saturated.
//
// All shell runs through groundcrew (no per-command approval prompts).

import { existsSync, mkdirSync, readdirSync, renameSync } from "node:fs";
import { join } from "node:path";
import { paths, SIMULATOR } from "../config.js";
import { fail, log, assertArtifact } from "../util.js";
import { gcRun } from "../groundcrew.js";

const DD = "/tmp/screenshot-dd";
const MIN = 60_000;

const FLOWS: Array<{ n: number; test: string; label: string }> = [
  { n: 1, test: "testFlow1_Capture", label: "capture modal: categories + due-date (one take)" },
  { n: 2, test: "testFlow2_NeedsAttention", label: "home: due summary / scroll" },
  { n: 3, test: "testFlow3_LookingBack", label: "home: Looking back buckets" },
  { n: 4, test: "testFlow4_Collections", label: "collections: grid + detail" },
];

// Run a step through groundcrew with retries disabled; fail the stage on error.
async function gcStep(desc: string, command: string, timeoutMs: number): Promise<string> {
  const res = await gcRun(command, { description: `stage02: ${desc}`, timeoutMs, retries: 0 });
  if (res.status !== "success" || (res.exitCode ?? 1) !== 0) {
    const detail = (res.stderr || res.stdout || "").trim().slice(-1500);
    fail("02", `${desc} failed (exit ${res.exitCode}):\n${detail}`);
  }
  return res.stdout;
}

// Refuse to start on an already-saturated machine (1-min load avg). Simulator
// boots and builds are heavy; piling them onto a wedged machine is how earlier
// runs spiralled. The threshold is generous — only guards against true runaway.
async function loadGuard(): Promise<void> {
  const out = (await gcStep("load check", `sysctl -n vm.loadavg`, MIN)).trim();
  // Format: "{ 12.34 10.00 9.00 }"
  const m = out.match(/\{\s*([\d.]+)/);
  const oneMin = m ? parseFloat(m[1]) : NaN;
  if (isFinite(oneMin)) {
    log("02", `system 1-min load: ${oneMin}`);
    if (oneMin > 60) {
      fail("02", `system load too high to start capture safely (1-min load ${oneMin}). ` +
        `Let the machine settle (close Xcode, stop stray simulators) and retry.`);
    }
  }
}

async function resolveDeviceUdid(): Promise<string> {
  const listCmd =
    `xcrun simctl list devices | grep "${SIMULATOR.name} (" | ` +
    `grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" | head -1`;
  let out = (await gcStep("resolve device", `${listCmd} || true`, MIN)).trim();
  if (out) return out;

  log("02", `creating simulator device ${SIMULATOR.name}`);
  await gcStep(
    "create device",
    `xcrun simctl create "${SIMULATOR.name}" "${SIMULATOR.deviceType}" ` +
      `"$(xcrun simctl list runtimes | grep -oE 'com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]+' | tail -1)"`,
    2 * MIN
  );
  out = (await gcStep("resolve device", listCmd, MIN)).trim();
  if (!out) fail("02", `could not resolve or create device ${SIMULATOR.name}`);
  return out;
}

export async function stageCapture(): Promise<void> {
  const stage = "02";

  // Archive any prior clips instead of wiping them (user preference): move them
  // into assets/app-capture-archive/<timestamp>/ so previous captures are never
  // silently destroyed. NOTE: these archives are not auto-pruned — clear out
  // assets/app-capture-archive/ yourself when you no longer need old captures.
  mkdirSync(paths.appCapture, { recursive: true });
  const priorMovs = existsSync(paths.appCapture)
    ? readdirSync(paths.appCapture).filter((f) => f.toLowerCase().endsWith(".mov"))
    : [];
  if (priorMovs.length > 0) {
    const stamp = new Date().toISOString().replace(/[:T]/g, "-").replace(/\..+/, "");
    const archiveDir = join(paths.assets, "app-capture-archive", stamp);
    mkdirSync(archiveDir, { recursive: true });
    for (const f of priorMovs) renameSync(join(paths.appCapture, f), join(archiveDir, f));
    log(stage, `archived ${priorMovs.length} prior clip(s) -> ${archiveDir}`);
    log(stage, `REMINDER: old captures accumulate in assets/app-capture-archive/ — clear it out when you're done with them.`);
  }

  await loadGuard();

  log(stage, "xcodegen generate");
  await gcStep("xcodegen generate", `xcodegen generate`, 3 * MIN);

  const udid = await resolveDeviceUdid();
  log(stage, `device ${SIMULATOR.name} -> ${udid}`);

  // Boot ONCE, wait for full boot, then let the first-boot daemon storm settle
  // before we do anything heavy.
  log(stage, "boot simulator (once) and wait for it to settle");
  await gcStep(
    "boot+settle",
    `xcrun simctl shutdown ${udid} 2>/dev/null; xcrun simctl boot ${udid}; ` +
      `xcrun simctl bootstatus ${udid} -b; sleep 15`,
    6 * MIN
  );

  log(stage, "build-for-testing (long)");
  await gcStep(
    "build-for-testing",
    `set -o pipefail; xcodebuild build-for-testing -scheme ${SIMULATOR.scheme} ` +
      `-configuration Debug -destination "platform=iOS Simulator,id=${udid}" ` +
      `-derivedDataPath ${DD} 2>&1 | tail -5`,
    25 * MIN
  );

  for (const flow of FLOWS) {
    const mov = `${paths.appCapture}/${flow.n}.mov`;
    log(stage, `flow ${flow.n} — ${flow.label}`);

    // Erase in place for identical state (R7) WITHOUT a full reboot: erase then
    // re-boot the same device. simctl erase requires the device shutdown, so we
    // shutdown->erase->boot, but only this one device, and we already paid the
    // heavy first-boot cost above so subsequent boots are lighter.
    await gcStep(
      `flow ${flow.n} reset`,
      `xcrun simctl shutdown ${udid}; xcrun simctl erase ${udid}; ` +
        `xcrun simctl boot ${udid}; xcrun simctl bootstatus ${udid} -b; sleep 3`,
      6 * MIN
    );

    // Record in background, run one flow, SIGINT the recorder to finalize the
    // .mov, wait for flush. Sent verbatim to bash; $REC/$TESTRC/$PIPESTATUS are
    // bash, not JS. retries: 0 (never re-run a recording).
    const runCmd = [
      "set -o pipefail",
      `xcrun simctl io ${udid} recordVideo --codec=h264 --force "${mov}" & REC=$!`,
      "sleep 2",
      `xcodebuild test-without-building -scheme ${SIMULATOR.scheme} -configuration Debug ` +
        `-destination "platform=iOS Simulator,id=${udid}" -derivedDataPath ${DD} ` +
        `-only-testing:ScreenshotUITests/ScreenshotUITests/${flow.test} 2>&1 | ` +
        `grep -iE "Test Case.*(passed|failed)|missing:|crashed|Testing failed" | tail -8`,
      "TESTRC=${PIPESTATUS[0]}",
      "sleep 1",
      "kill -INT $REC 2>/dev/null || true",
      "wait $REC 2>/dev/null || true",
      'echo "TESTRC=$TESTRC"',
      'test "$TESTRC" -eq 0',
    ].join("; ");

    const out = await gcRun(runCmd, {
      description: `stage02: flow ${flow.n} record+test`,
      timeoutMs: 12 * MIN,
      retries: 0,
    });
    if (out.status !== "success" || (out.exitCode ?? 1) !== 0) {
      const detail = (out.stdout || out.stderr || "").trim().slice(-1500);
      fail(stage, `flow ${flow.n} (${flow.test}) failed:\n${detail}`);
    }

    await gcStep(`flow ${flow.n} verify mov`, `test -s "${mov}" && ls -l "${mov}"`, MIN);
    log(stage, `flow ${flow.n} -> ${flow.n}.mov`);
  }

  // Leave the device shut down so it isn't left storming after the stage.
  await gcStep("shutdown device", `xcrun simctl shutdown ${udid} 2>/dev/null || true`, MIN);

  for (const flow of FLOWS) {
    assertArtifact("02", `${paths.appCapture}/${flow.n}.mov`, "capture clip");
  }
  log(stage, `captured ${FLOWS.length} flows -> ${paths.appCapture}`);
}
