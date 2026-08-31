// Orchestrator. `npm run video` runs all five stages in order and produces
// out/screenshot-demo.mp4 (R1). Flags:
//   --check-env            verify toolchain + env vars, exit zero if ready (0.1/0.2)
//   --only <stage>         run a single stage: 01|02|03|04|05 (N3)
//   --regenerate-script    force stage 1 to rewrite assets/script.json (R3)
//
// Any stage failure exits non-zero naming the failing stage (N2).

import { mkdirSync } from "node:fs";
import { paths } from "./config.js";
import { StageError, log } from "./util.js";
import { checkEnv } from "./stages/00-check-env.js";
import { stageScript } from "./stages/01-script.js";
import { stageCapture } from "./stages/02-capture.js";
import { stageVoice } from "./stages/03-voice.js";
import { stageRender } from "./stages/04-render.js";
import { stageAssemble } from "./stages/05-assemble.js";

type StageId = "01" | "02" | "03" | "04" | "05";

interface Args {
  checkEnv: boolean;
  only?: StageId;
  regenerateScript: boolean;
}

function parseArgs(argv: string[]): Args {
  const a: Args = { checkEnv: false, regenerateScript: false };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--check-env") a.checkEnv = true;
    else if (arg === "--regenerate-script") a.regenerateScript = true;
    else if (arg === "--only") {
      const v = argv[++i];
      if (!["01", "02", "03", "04", "05"].includes(v)) {
        console.error(`--only expects one of 01|02|03|04|05, got: ${v}`);
        process.exit(2);
      }
      a.only = v as StageId;
    }
  }
  return a;
}

function ensureDirs(): void {
  for (const d of [paths.assets, paths.appCapture, paths.vo, paths.scenes, paths.music, paths.out]) {
    mkdirSync(d, { recursive: true });
  }
}

const STAGES: Record<StageId, (opts: { regenerateScript?: boolean }) => Promise<void>> = {
  "01": (o) => stageScript(o),
  "02": () => stageCapture(),
  "03": () => stageVoice(),
  "04": () => stageRender(),
  "05": () => stageAssemble(),
};

async function main(): Promise<void> {
  const args = parseArgs(process.argv.slice(2));

  if (args.checkEnv) {
    await checkEnv();
    log("run", "environment OK");
    return;
  }

  ensureDirs();

  const order: StageId[] = args.only ? [args.only] : ["01", "02", "03", "04", "05"];
  for (const id of order) {
    log("run", `starting stage ${id}`);
    await STAGES[id]({ regenerateScript: args.regenerateScript });
    log("run", `stage ${id} complete`);
  }

  if (!args.only) log("run", `done -> ${paths.outFile}`);
}

main().catch((err) => {
  if (err instanceof StageError) {
    console.error(`\n\x1b[31mFAILED\x1b[0m ${err.message}`);
  } else {
    console.error(`\n\x1b[31mFAILED\x1b[0m ${err?.stack ?? err}`);
  }
  process.exit(1);
});
