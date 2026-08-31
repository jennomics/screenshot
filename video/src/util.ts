// Shared helpers: process exec, artifact validation, and the stage-failure
// contract (N2 — any stage failure exits non-zero naming the failing stage; no
// stage produces a partial artifact silently).

import { spawn } from "node:child_process";
import { existsSync, statSync } from "node:fs";

export class StageError extends Error {
  constructor(public stage: string, message: string) {
    super(`[stage ${stage}] ${message}`);
    this.name = "StageError";
  }
}

export function fail(stage: string, message: string): never {
  throw new StageError(stage, message);
}

// Run a command, streaming its output. Rejects on non-zero exit.
export function run(
  cmd: string,
  args: string[],
  opts: { cwd?: string; env?: NodeJS.ProcessEnv; quiet?: boolean } = {}
): Promise<{ stdout: string; stderr: string }> {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      cwd: opts.cwd,
      env: opts.env ?? process.env,
      stdio: opts.quiet ? ["ignore", "pipe", "pipe"] : ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (d) => {
      stdout += d;
      if (!opts.quiet) process.stdout.write(d);
    });
    child.stderr.on("data", (d) => {
      stderr += d;
      if (!opts.quiet) process.stderr.write(d);
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve({ stdout, stderr });
      else reject(new Error(`${cmd} ${args.join(" ")} exited ${code}\n${stderr}`));
    });
  });
}

// Capture stdout only, no streaming (for probes/queries).
export async function capture(cmd: string, args: string[]): Promise<string> {
  const { stdout } = await run(cmd, args, { quiet: true });
  return stdout;
}

// Assert an artifact exists and is non-zero-byte, else fail the named stage.
export function assertArtifact(stage: string, path: string, label = "artifact"): void {
  if (!existsSync(path)) fail(stage, `${label} missing: ${path}`);
  const size = statSync(path).size;
  if (size === 0) fail(stage, `${label} is zero bytes: ${path}`);
}

export async function ffprobeDurationSec(path: string): Promise<number> {
  const out = await capture("ffprobe", [
    "-v", "error",
    "-show_entries", "format=duration",
    "-of", "default=noprint_wrappers=1:nokey=1",
    path,
  ]);
  const n = parseFloat(out.trim());
  if (!isFinite(n) || n <= 0) throw new Error(`ffprobe could not read duration of ${path}`);
  return n;
}

export function log(stage: string, msg: string): void {
  console.log(`\x1b[36m[${stage}]\x1b[0m ${msg}`);
}
