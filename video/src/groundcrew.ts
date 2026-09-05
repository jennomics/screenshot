// Groundcrew execution channel.
//
// The pipeline routes its shell work (xcodegen, xcodebuild, simctl capture,
// ffprobe/ffmpeg, Remotion render) through groundcrew's HTTP API instead of
// running commands directly, so the operator isn't prompted to approve each
// one. Groundcrew runs the command locally, logs it, and returns stdout /
// stderr / exitCode.
//
// Contract (groundcrew v0.4.0):
//   POST /_gc/commands  { command, description?, source?, timeout? }
//                       -> 201 { id, status: "pending"|"running", ... }
//       Auth: Authorization: Bearer $GC_AUTH_TOKEN
//       `timeout` (ms) is the per-command override we wired through the API.
//   GET  /_gc/commands  -> { commands: StoredCommand[] }   (poll by id)
//
// The base URL comes from GROUNDCREW_URL if set, else the latest "Tunnel
// active:" line in ~/.groundcrew/groundcrew.log. The screenshot repo is not a
// registered groundcrew project, so commands are cd-prefixed into the repo
// root (groundcrew otherwise runs in the first registered project's dir).

import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { REPO_ROOT } from "./config.js";

const GC_LOG = join(homedir(), ".groundcrew", "groundcrew.log");

export interface StoredCommand {
  id: string;
  command: string;
  status: "pending" | "running" | "success" | "failed";
  stdout: string;
  stderr: string;
  exitCode: number | null;
  duration: number | null;
}

export interface GcResult {
  stdout: string;
  stderr: string;
  exitCode: number | null;
  status: string;
}

let cachedBase: string | null = null;

function resolveBaseUrl(): string {
  if (cachedBase) return cachedBase;

  const fromEnv = process.env.GROUNDCREW_URL?.trim();
  if (fromEnv) {
    cachedBase = fromEnv.replace(/\/+$/, "");
    return cachedBase;
  }

  if (existsSync(GC_LOG)) {
    const log = readFileSync(GC_LOG, "utf8");
    // Last "Tunnel active: <url>" wins (most recent restart).
    const matches = [...log.matchAll(/Tunnel active:\s*(https:\/\/[a-z0-9-]+\.trycloudflare\.com)/gi)];
    if (matches.length > 0) {
      cachedBase = matches[matches.length - 1][1];
      return cachedBase;
    }
  }

  // Fall back to the local API port so the pipeline still works when run on the
  // same machine as groundcrew even if the tunnel/log is unavailable.
  cachedBase = "http://localhost:4747";
  return cachedBase;
}

function authToken(): string {
  const t = process.env.GC_AUTH_TOKEN;
  if (!t || !t.trim()) {
    throw new Error("GC_AUTH_TOKEN is not set; groundcrew POST requires it. Source ~/.zshrc before running.");
  }
  return t;
}

const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

interface RunOptions {
  description?: string;
  timeoutMs?: number; // per-command executor timeout (groundcrew-side)
  retries?: number; // per-command retry count (0..3). Set 0 for side-effecting
  // commands (sim boot/record, builds) so a transient failure never re-runs the
  // whole command (a re-boot triggers another simulator daemon storm).
  cwd?: string; // absolute; defaults to the screenshot repo root
  pollIntervalMs?: number;
  clientTimeoutMs?: number; // give up polling after this (client-side safety)
}

// Run a command through groundcrew and resolve when it reaches a terminal
// state. Does NOT throw on non-zero exit — callers inspect exitCode so they can
// attach stage context to failures (N2).
export async function gcRun(command: string, opts: RunOptions = {}): Promise<GcResult> {
  const base = resolveBaseUrl();
  const token = authToken();
  const cwd = opts.cwd ?? REPO_ROOT;

  // cd into the target dir; groundcrew runs bash -c so this composes cleanly.
  const wrapped = `cd ${JSON.stringify(cwd)} && ${command}`;

  const body: Record<string, unknown> = {
    command: wrapped,
    description: opts.description ?? "screenshot video pipeline",
    source: "video-pipeline",
  };
  if (opts.timeoutMs !== undefined) body.timeout = opts.timeoutMs;
  if (opts.retries !== undefined) body.retries = opts.retries;

  const postRes = await fetch(`${base}/_gc/commands`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });

  if (postRes.status === 401 || postRes.status === 403) {
    throw new Error(`groundcrew auth rejected (HTTP ${postRes.status}). Check GC_AUTH_TOKEN.`);
  }
  if (!postRes.ok) {
    const text = await postRes.text().catch(() => "");
    throw new Error(`groundcrew POST failed (HTTP ${postRes.status}): ${text}`);
  }

  const queued = (await postRes.json()) as StoredCommand;
  const id = queued.id;

  const pollInterval = opts.pollIntervalMs ?? 1500;
  // Client-side poll ceiling: a little longer than the executor timeout so we
  // don't give up before groundcrew itself does. Default generous.
  const clientCeiling = opts.clientTimeoutMs ?? (opts.timeoutMs ?? 120_000) + 30_000;
  const start = Date.now();

  for (;;) {
    if (Date.now() - start > clientCeiling) {
      throw new Error(`groundcrew command did not finish within ${clientCeiling}ms (id ${id}): ${command}`);
    }
    await sleep(pollInterval);

    const listRes = await fetch(`${base}/_gc/commands`);
    if (!listRes.ok) continue; // transient; keep polling
    const { commands } = (await listRes.json()) as { commands: StoredCommand[] };
    const cmd = commands.find((c) => c.id === id);
    if (!cmd) continue;
    if (cmd.status === "success" || cmd.status === "failed") {
      return { stdout: cmd.stdout, stderr: cmd.stderr, exitCode: cmd.exitCode, status: cmd.status };
    }
  }
}

// Convenience: run and throw a StageError-friendly message on failure.
export async function gcRunOrThrow(
  stage: string,
  command: string,
  opts: RunOptions = {}
): Promise<GcResult> {
  const res = await gcRun(command, opts);
  if (res.status !== "success" || (res.exitCode ?? 1) !== 0) {
    const err = res.stderr?.trim() || res.stdout?.trim() || "(no output)";
    throw new Error(`[stage ${stage}] command failed (exit ${res.exitCode}, status ${res.status}):\n${command}\n${err}`);
  }
  return res;
}

// Health check used by --check-env: confirms the API is reachable and auth works.
export async function gcHealth(): Promise<{ ok: boolean; base: string; detail: string }> {
  const base = resolveBaseUrl();
  try {
    const res = await fetch(`${base}/_gc/status`);
    if (!res.ok) return { ok: false, base, detail: `status HTTP ${res.status}` };
    const j = (await res.json()) as { version?: string };
    return { ok: true, base, detail: `groundcrew ${j.version ?? "?"}` };
  } catch (e) {
    return { ok: false, base, detail: e instanceof Error ? e.message : String(e) };
  }
}
