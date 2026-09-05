// Remotion scene compositions. Four scene types:
//   ProblemScene, SolutionScene, CloseScene  — typography + motion only (V4: no
//                                               fake UI drawn in Remotion)
//   AppScene  — real captured .mov inside a phone frame, slow scale/pan; the
//               only place app footage appears
//
// All read the palette/type tokens mirrored from the app's Theme.swift.

import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
  OffthreadVideo,
  Sequence,
  staticFile,
} from "remotion";
import { Palette, ink, Space, Text } from "./theme";
import { ensureFonts } from "./fonts";

export interface FocusKeyframe {
  atSec: number; // time into the scene
  scale: number; // zoom factor
  panY: number; // vertical shift inside the scale (px); - up, + down
}

export interface SceneProps {
  onScreenText: string;
  // AppScene only:
  clipSrc?: string; // staticFile path to the .mov
  trimStartSec?: number; // where the app window begins in the source clip
  focus?: FocusKeyframe[]; // VO-timed camera keyframes (scale + vertical pan)
  noFadeIn?: boolean; // hard cut in (continuous move from previous app scene)
  noFadeOut?: boolean; // hard cut out (continuous move into next app scene)
}

const fadeIn = (frame: number, dur = 18) => interpolate(frame, [0, dur], [0, 1], { extrapolateRight: "clamp" });
const fadeOut = (frame: number, total: number, dur = 16) =>
  interpolate(frame, [total - dur, total], [1, 0], { extrapolateLeft: "clamp" });

// ---- Problem: dark-to-paper, phrases settle in the display face ----
export const ProblemScene: React.FC<SceneProps> = ({ onScreenText }) => {
  ensureFonts();
  const frame = useCurrentFrame();
  const { durationInFrames, fps } = useVideoConfig();
  const rise = spring({ frame, fps, config: { damping: 200 }, durationInFrames: 30 });
  const y = interpolate(rise, [0, 1], [40, 0]);
  const opacity = Math.min(fadeIn(frame), fadeOut(frame, durationInFrames));

  return (
    <AbsoluteFill style={{ backgroundColor: Palette.ink, justifyContent: "center", alignItems: "center", padding: Space.s6 }}>
      <div style={{ opacity, transform: `translateY(${y}px)`, textAlign: "center", maxWidth: 1400 }}>
        <div style={{ ...Text.h1, color: Palette.paper, lineHeight: 1.15 }}>{onScreenText}</div>
      </div>
    </AbsoluteFill>
  );
};

// ---- Solution: paper ground, terracotta rule draws across ----
export const SolutionScene: React.FC<SceneProps> = ({ onScreenText }) => {
  ensureFonts();
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const opacity = Math.min(fadeIn(frame), fadeOut(frame, durationInFrames));
  const ruleW = interpolate(frame, [10, 40], [0, 360], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ backgroundColor: Palette.paper, justifyContent: "center", alignItems: "center", padding: Space.s6 }}>
      <div style={{ opacity, textAlign: "center", maxWidth: 1500 }}>
        <div style={{ ...Text.meta, color: ink(0.5), marginBottom: Space.s3 }}>SCREENSHOT</div>
        <div style={{ ...Text.h1, color: Palette.ink, lineHeight: 1.12 }}>{onScreenText}</div>
        <div style={{ height: 6, width: ruleW, backgroundColor: Palette.live, margin: `${Space.s4}px auto 0` }} />
      </div>
    </AbsoluteFill>
  );
};

// ---- Close: title card + tagline, terracotta underline, hold, fade ----
export const CloseScene: React.FC<SceneProps> = ({ onScreenText }) => {
  ensureFonts();
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const opacity = Math.min(fadeIn(frame), fadeOut(frame, durationInFrames));

  return (
    <AbsoluteFill style={{ backgroundColor: Palette.paper, justifyContent: "center", alignItems: "center", padding: Space.s6 }}>
      <div style={{ opacity, textAlign: "center" }}>
        <div style={{ ...Text.display, color: Palette.ink }}>Screenshot</div>
        <div style={{ ...Text.h3, color: ink(0.7), marginTop: Space.s3 }}>{onScreenText}</div>
        <div style={{ height: 6, width: 240, backgroundColor: Palette.live, margin: `${Space.s3}px auto 0` }} />
      </div>
    </AbsoluteFill>
  );
};

// ---- App: real .mov inside a phone frame, camera move (scale + vertical pan) ----
export const AppScene: React.FC<SceneProps> = ({
  clipSrc,
  trimStartSec = 0,
  onScreenText,
  focus,
  noFadeIn = false,
  noFadeOut = false,
}) => {
  ensureFonts();
  const frame = useCurrentFrame();
  const { durationInFrames, fps } = useVideoConfig();

  // Phone frame geometry for iPhone 16 Pro logical res (1206x2622). Scale the
  // frame to fit the 1080-tall canvas with headroom.
  const phoneH = 980;
  const phoneW = phoneH * (1206 / 2622);
  const radius = 64;

  // Camera move. If `focus` keyframes are provided, interpolate scale + vertical
  // pan through them (times in seconds -> frames), timed to the narration so a
  // target is framed exactly as the words land. `panY` is applied inside the
  // scale: negative reveals the UPPER part of the phone, positive the LOWER.
  // Without keyframes, a gentle default Ken Burns.
  let scale: number;
  let pan: number;
  if (focus && focus.length > 0) {
    const times = focus.map((k) => Math.round(k.atSec * fps));
    scale = interpolate(frame, times, focus.map((k) => k.scale), {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
    pan = interpolate(frame, times, focus.map((k) => k.panY), {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    });
  } else {
    // Hold still by default — no idle drift. The phone stays put unless a
    // camera move is actually serving a purpose (the capture zoom/pan).
    scale = 1.0;
    pan = 0;
  }

  // Opacity fades, unless suppressed at a boundary for a hard cut / continuous
  // move between adjacent app scenes.
  const fin = noFadeIn ? 1 : fadeIn(frame);
  const fout = noFadeOut ? 1 : fadeOut(frame, durationInFrames);
  const opacity = Math.min(fin, fout);

  const label = onScreenText?.trim();

  return (
    <AbsoluteFill style={{ backgroundColor: Palette.paper, justifyContent: "center", alignItems: "center" }}>
      {/* subtle live-wash panel behind the phone */}
      <AbsoluteFill style={{ background: `radial-gradient(circle at 50% 40%, ${Palette.liveWash}, ${Palette.paper})` }} />

      <div
        style={{
          width: phoneW,
          height: phoneH,
          borderRadius: radius,
          overflow: "hidden",
          border: `10px solid ${Palette.ink}`,
          boxSizing: "content-box",
          transform: `scale(${scale}) translateY(${pan}px)`,
          opacity,
          backgroundColor: "#000",
          zIndex: 1,
        }}
      >
        {clipSrc ? (
          <OffthreadVideo
            src={staticFile(clipSrc)}
            startFrom={Math.round(trimStartSec * fps)}
            style={{ width: "100%", height: "100%", objectFit: "cover" }}
            muted
          />
        ) : null}
      </div>

      {/* Section label pinned to the top, ON TOP of the phone (z-order), on a
          paper pill so it stays readable over the footage. */}
      {label ? (
        <div
          style={{
            position: "absolute",
            top: Space.s4,
            zIndex: 2,
            ...Text.meta,
            color: Palette.live,
            opacity,
            backgroundColor: Palette.paper,
            border: `1px solid ${Palette.rule}`,
            padding: `${Space.s1}px ${Space.s2}px`,
            borderRadius: 4,
          }}
        >
          {label.toUpperCase()}
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

// Map a scene `type` to its component.
export const SCENE_COMPONENTS = {
  problem: ProblemScene,
  solution: SolutionScene,
  app: AppScene,
  close: CloseScene,
} as const;
