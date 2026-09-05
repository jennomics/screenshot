// Register the bundled design fonts with Remotion so animated scenes render in
// Zen Kaku Gothic New + DM Mono, matching the app footage. The TTFs live in the
// app target (App/Fonts); we load them from there via staticFile after copying
// into the Remotion public/ dir at bundle time (see render driver).

import { continueRender, delayRender, staticFile } from "remotion";

let started = false;

export function ensureFonts(): void {
  if (started || typeof document === "undefined") return;
  started = true;

  const faces: Array<{ family: string; file: string; weight: number }> = [
    { family: "Zen Kaku Gothic New", file: "ZenKakuGothicNew-Regular.ttf", weight: 400 },
    { family: "Zen Kaku Gothic New", file: "ZenKakuGothicNew-Medium.ttf", weight: 500 },
    { family: "Zen Kaku Gothic New", file: "ZenKakuGothicNew-Bold.ttf", weight: 700 },
    { family: "Zen Kaku Gothic New", file: "ZenKakuGothicNew-Black.ttf", weight: 900 },
    { family: "DM Mono", file: "DMMono-Regular.ttf", weight: 400 },
    { family: "DM Mono", file: "DMMono-Medium.ttf", weight: 500 },
  ];

  for (const f of faces) {
    const handle = delayRender(`font ${f.file}`);
    const face = new FontFace(f.family, `url(${staticFile("fonts/" + f.file)})`, {
      weight: String(f.weight),
    });
    face
      .load()
      .then((loaded) => {
        (document as unknown as { fonts: FontFaceSet }).fonts.add(loaded);
        continueRender(handle);
      })
      .catch(() => continueRender(handle));
  }
}
