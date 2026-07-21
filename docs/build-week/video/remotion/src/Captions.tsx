import { parseSrt, type Caption } from "@remotion/captions";
import {
  AbsoluteFill,
  staticFile,
  useCurrentFrame,
  useDelayRender,
  useVideoConfig,
} from "remotion";
import { useCallback, useEffect, useMemo, useState } from "react";

export const NarrationCaptions: React.FC = () => {
  const [captions, setCaptions] = useState<Caption[] | null>(null);
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { cancelRender, continueRender, delayRender } = useDelayRender();
  const [captionHandle] = useState(() =>
    delayRender("Load narration captions"),
  );

  const loadCaptions = useCallback(async () => {
    try {
      const response = await fetch(staticFile("captions/narration-en.srt"));
      const input = await response.text();
      setCaptions(parseSrt({ input }).captions);
      continueRender(captionHandle);
    } catch (error) {
      cancelRender(error);
    }
  }, [cancelRender, captionHandle, continueRender]);

  useEffect(() => {
    loadCaptions();
  }, [loadCaptions]);

  const active = useMemo(() => {
    const currentMs = (frame / fps) * 1000;
    return captions?.find(
      (caption) => caption.startMs <= currentMs && caption.endMs > currentMs,
    );
  }, [captions, frame, fps]);

  if (!active) {
    return null;
  }

  return (
    <AbsoluteFill className="caption-layer">
      <div className="caption-box">{active.text.trim()}</div>
    </AbsoluteFill>
  );
};
