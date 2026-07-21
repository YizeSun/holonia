import { Composition } from "remotion";
import { NearBridgeVideo } from "./NearBridgeVideo";

export const NearBridgeComposition: React.FC = () => {
  return (
    <Composition
      id="NearBridgeBuildWeek"
      component={NearBridgeVideo}
      durationInFrames={5100}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
