// Remotion root. A single parametric composition "Scene" renders any one scene
// from input props; the render driver (stage 4) invokes it once per scene with
// that scene's props + computed duration, producing assets/scenes/*.mp4. Stage 5
// concatenates them.

import React from "react";
import { Composition } from "remotion";
import { z } from "zod";
import { SCENE_COMPONENTS } from "./scenes";
import { OUTPUT } from "./output";

export const sceneInputSchema = z.object({
  type: z.enum(["problem", "solution", "app", "close"]),
  onScreenText: z.string(),
  clipSrc: z.string().optional(),
  trimStartSec: z.number().optional(),
  focus: z
    .array(z.object({ atSec: z.number(), scale: z.number(), panY: z.number() }))
    .optional(),
  noFadeIn: z.boolean().optional(),
  noFadeOut: z.boolean().optional(),
  durationInFrames: z.number().int().positive(),
});

export type SceneInput = z.infer<typeof sceneInputSchema>;

const SceneRenderer: React.FC<SceneInput> = (props) => {
  const Comp = SCENE_COMPONENTS[props.type];
  return (
    <Comp
      onScreenText={props.onScreenText}
      clipSrc={props.clipSrc}
      trimStartSec={props.trimStartSec}
      focus={props.focus}
      noFadeIn={props.noFadeIn}
      noFadeOut={props.noFadeOut}
    />
  );
};

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="Scene"
      component={SceneRenderer}
      durationInFrames={150}
      fps={OUTPUT.fps}
      width={OUTPUT.width}
      height={OUTPUT.height}
      schema={sceneInputSchema}
      defaultProps={{
        type: "problem" as const,
        onScreenText: "preview",
        durationInFrames: 150,
      }}
      calculateMetadata={({ props }) => ({ durationInFrames: props.durationInFrames })}
    />
  );
};
