// Browser-safe output constants for the Remotion bundle (kept separate from
// src/config.ts which imports node:fs and can't be bundled for the browser).
export const OUTPUT = { width: 1920, height: 1080, fps: 30 } as const;
