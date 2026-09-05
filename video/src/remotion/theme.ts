// Design tokens mirrored 1:1 from ScreenshotKit/Sources/ScreenshotKit/Design/
// Theme.swift so the animated Remotion scenes and the real app footage read as
// one product. Keep in sync if Theme.swift changes.

export const Palette = {
  paper: "#F6F5F1",
  rule: "#E6E4DC",
  live: "#A8512C", // terracotta accent
  ink: "#1C1C1A",
  liveWash: "#F1E6E0",
  overdue: "#A8302C",
} as const;

export const ink = (opacity: number) => `rgba(28, 28, 26, ${opacity})`;

// Spacing scale: 8 / 16 / 24 / 40 / 64 / 104
export const Space = { s1: 8, s2: 16, s3: 24, s4: 40, s5: 64, s6: 104 } as const;

// Typefaces. The app bundles these (App/Fonts) and the video bundles the same
// TTFs (see fonts.ts) so typography matches the footage.
export const Type = {
  zen: "Zen Kaku Gothic New",
  mono: "DM Mono",
} as const;

// Font sizes scaled up for 1080p canvas (the app sizes target a phone screen;
// full-frame typography wants to be larger). Weights map to bundled files.
export const Text = {
  display: { fontFamily: Type.zen, fontWeight: 900, fontSize: 132 },
  h1: { fontFamily: Type.zen, fontWeight: 800, fontSize: 84 },
  h2: { fontFamily: Type.zen, fontWeight: 700, fontSize: 60 },
  h3: { fontFamily: Type.zen, fontWeight: 700, fontSize: 44 },
  body: { fontFamily: Type.zen, fontWeight: 400, fontSize: 34 },
  meta: { fontFamily: Type.mono, fontWeight: 400, fontSize: 22, letterSpacing: 2 },
} as const;
