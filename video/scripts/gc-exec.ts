// Ad-hoc groundcrew command runner: reads a shell command from argv and runs
// it through the pipeline's groundcrew client (cd's into the repo root),
// streaming the result. Handy for one-off repo operations without approval
// prompts. Usage: tsx scripts/gc-exec.ts "<command>" [timeoutMs]
import { gcRun } from "../src/groundcrew.js";

const command = process.argv[2];
const timeoutMs = process.argv[3] ? parseInt(process.argv[3], 10) : 120_000;
if (!command) {
  console.error("usage: tsx scripts/gc-exec.ts \"<command>\" [timeoutMs]");
  process.exit(2);
}

const res = await gcRun(command, { description: "ad-hoc repo op", timeoutMs });
process.stdout.write(res.stdout);
if (res.stderr.trim()) process.stderr.write("\n[stderr]\n" + res.stderr);
console.log(`\n[groundcrew] status=${res.status} exit=${res.exitCode}`);
process.exit(res.status === "success" && (res.exitCode ?? 1) === 0 ? 0 : 1);
