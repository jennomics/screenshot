// The script contract shared by every stage after stage 1. This is the single
// data structure the pipeline flows through (see data-flow diagram in design).

import { z } from "zod";
import { readFileSync, writeFileSync } from "node:fs";

// Scene types map to Remotion compositions. `app` scenes embed real simulator
// footage; the others are pure typography/motion (V4 — no UI drawn in Remotion).
export const SceneType = z.enum(["problem", "solution", "app", "close"]);

export const SceneSchema = z.object({
  id: z.string().min(1),
  type: SceneType,
  durationSec: z.number().positive(),
  vo: z.string().min(1),
  visual: z.string().min(1),
  onScreenText: z.string(),
  // For `app` scenes: which captured flow (1..5) this scene shows. Not part of
  // the original Bedrock contract, but required to bind footage to scenes now
  // that the script is authored directly. Optional for non-app scenes.
  captureFlow: z.number().int().positive().optional(),
  // Written back by stage 3 after synthesis + ffprobe.
  actualVoSec: z.number().positive().optional(),
});

export const ScriptSchema = z.object({
  scenes: z.array(SceneSchema).min(1),
});

export type Scene = z.infer<typeof SceneSchema>;
export type Script = z.infer<typeof ScriptSchema>;

// Strict load: fail loudly, never repair by guessing (design stage 1).
export function loadScript(path: string): Script {
  const raw = readFileSync(path, "utf8");
  const parsed = JSON.parse(raw);
  const result = ScriptSchema.safeParse(parsed);
  if (!result.success) {
    throw new Error(`script.json failed validation:\n${result.error.toString()}`);
  }
  // Cross-field: every `app` scene must name a capture flow.
  for (const s of result.data.scenes) {
    if (s.type === "app" && s.captureFlow === undefined) {
      throw new Error(`app scene "${s.id}" is missing captureFlow`);
    }
  }
  return result.data;
}

export function saveScript(path: string, script: Script): void {
  const validated = ScriptSchema.parse(script);
  writeFileSync(path, JSON.stringify(validated, null, 2) + "\n");
}

// Effective on-screen duration in seconds (R9 — extend the scene for long VO,
// never truncate the audio). +0.5s tail so speech doesn't butt the cut.
export function sceneDurationSec(s: Scene): number {
  const vo = s.actualVoSec ?? 0;
  return Math.max(s.durationSec, vo + 0.5);
}
