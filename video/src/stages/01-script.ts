// Stage 1 — script.
//
// The design originally called Bedrock here. That dependency is removed: there
// are no AWS credentials on this machine, the artifact is a one-time creative
// brief, and a live LLM call at render time only adds nondeterminism to a
// cached output (R3). The script is authored directly and checked in at
// assets/script.json. This stage's job is to guarantee the contract holds
// before anything downstream depends on it — validate strictly, fail loudly,
// never repair by guessing (design stage 1).
//
// --regenerate-script is retained as a manual hook. With no model backend it
// re-validates the existing file rather than overwriting it; regeneration is a
// human edit to script.json, not an automated call.

import { existsSync } from "node:fs";
import { paths } from "../config.js";
import { fail, log } from "../util.js";
import { loadScript } from "../script.js";

export async function stageScript(opts: { regenerateScript?: boolean }): Promise<void> {
  const stage = "01";

  if (!existsSync(paths.script)) {
    fail(
      stage,
      `assets/script.json not found. The script is authored directly (no Bedrock backend). ` +
        `Create ${paths.script} following the scene contract.`
    );
  }

  if (opts.regenerateScript) {
    log(stage, "--regenerate-script: no model backend; re-validating the authored script.json in place");
  }

  let script;
  try {
    script = loadScript(paths.script);
  } catch (e) {
    fail(stage, `script.json failed validation: ${e instanceof Error ? e.message : String(e)}`);
  }

  const total = script.scenes.reduce((s, sc) => s + sc.durationSec, 0);
  const appScenes = script.scenes.filter((s) => s.type === "app");

  log(stage, `${script.scenes.length} scenes, ${appScenes.length} app scenes, base runtime ${total}s`);

  // A1: 60-75s target. Warn (don't fail) if base durations fall outside — the
  // effective runtime shifts once voiceover lengths are measured in stage 3.
  if (total < 55 || total > 80) {
    log(stage, `WARNING: base runtime ${total}s is outside the 60-75s target band`);
  }

  // Every app scene must bind to a distinct capture flow (1..5 per R6).
  const flows = appScenes.map((s) => s.captureFlow!);
  const uniqueFlows = new Set(flows);
  if (uniqueFlows.size !== flows.length) {
    fail(stage, `app scenes have duplicate captureFlow bindings: ${flows.join(", ")}`);
  }

  log(stage, `validated -> ${paths.script}`);
}
