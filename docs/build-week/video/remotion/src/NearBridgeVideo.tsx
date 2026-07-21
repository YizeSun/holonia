import { Audio, Video } from "@remotion/media";
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";
import { NarrationCaptions } from "./Captions";

const Card: React.FC<{ file: string; label: string }> = ({ file, label }) => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill className="card-scene">
      <Img
        src={staticFile(`cards/${file}`)}
        alt={label}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          opacity: interpolate(frame, [0, 16], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
          scale: interpolate(frame, [0, 360], [1.015, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      />
    </AbsoluteFill>
  );
};

const Stage: React.FC<{
  eyebrow: string;
  title: string;
  detail: string;
  children: React.ReactNode;
}> = ({ eyebrow, title, detail, children }) => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill className="stage">
      <div
        className="stage-header"
        style={{
          opacity: interpolate(frame, [0, 12], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: `0 ${interpolate(frame, [0, 12], [18, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}px`,
        }}
      >
        <div className="eyebrow">{eyebrow}</div>
        <div className="stage-title">{title}</div>
        <div className="stage-detail">{detail}</div>
      </div>
      <div className="device-area">{children}</div>
    </AbsoluteFill>
  );
};

const DeviceFrame: React.FC<{
  kind: "iphone" | "mac";
  children: React.ReactNode;
  className?: string;
}> = ({ kind, children, className = "" }) => {
  return (
    <div className={`device-frame ${kind} ${className}`}>
      <div className="device-label">{kind === "iphone" ? "iPhone" : "Mac Host"}</div>
      <div className="device-screen">{children}</div>
    </div>
  );
};

const BrollRelationship: React.FC = () => {
  return (
    <AbsoluteFill className="relationship">
      <div className="relationship-media">
        <DeviceFrame kind="iphone">
          <Video
            src={staticFile("raw/iphone.mp4")}
            trimBefore={0}
            muted
            className="iphone-video"
          />
        </DeviceFrame>
        <DeviceFrame kind="mac">
          <Video
            src={staticFile("raw/mac.mov")}
            trimBefore={361}
            muted
            className="mac-video"
          />
        </DeviceFrame>
      </div>
      <div className="relationship-shade" />
      <div className="relationship-copy">
        <div className="eyebrow">NEARBRIDGE</div>
        <div className="relationship-title">Holonia’s first working edge</div>
        <div className="relationship-detail">
          iPhone → authenticated local session → Mac Host policy → signed answer
        </div>
      </div>
    </AbsoluteFill>
  );
};

const DiscoveryScene: React.FC = () => {
  return (
    <Stage
      eyebrow="PHYSICAL PROOF · 1"
      title="Nearby does not mean trusted"
      detail="Both user-launched apps discover one another on the same Wi-Fi."
    >
      <DeviceFrame kind="iphone">
        <Video
          src={staticFile("raw/iphone.mp4")}
          trimBefore={240}
          muted
          className="iphone-video"
        />
      </DeviceFrame>
      <DeviceFrame kind="mac">
        <Video
          src={staticFile("raw/mac.mov")}
          trimBefore={601}
          muted
          className="mac-video"
        />
      </DeviceFrame>
      <div className="callout warning">Discovery ≠ authentication</div>
    </Stage>
  );
};

const PairingScene: React.FC = () => {
  return (
    <Stage
      eyebrow="PHYSICAL PROOF · 2"
      title="One code. Two explicit approvals."
      detail="The same six-digit code binds approved device keys to a fresh session."
    >
      <DeviceFrame kind="iphone" className="dominant-phone">
        <Video
          src={staticFile("raw/iphone.mp4")}
          trimBefore={570}
          muted
          className="iphone-video"
        />
      </DeviceFrame>
      <DeviceFrame kind="mac" className="supporting-mac">
        <Video
          src={staticFile("raw/mac.mov")}
          trimBefore={931}
          muted
          className="mac-video mac-zoom-pairing"
        />
      </DeviceFrame>
      <div className="callout success">Authenticated fresh session</div>
    </Stage>
  );
};

const ContactScene: React.FC = () => {
  return (
    <Stage
      eyebrow="PHYSICAL PROOF · 3"
      title="The Host selects what is available"
      detail="A signed four-step contact workflow approves one narrow capability."
    >
      <DeviceFrame kind="iphone">
        <Video
          src={staticFile("raw/iphone.mp4")}
          trimBefore={960}
          muted
          className="iphone-video"
        />
      </DeviceFrame>
      <DeviceFrame kind="mac">
        <Video
          src={staticFile("raw/mac.mov")}
          trimBefore={1321}
          muted
          className="mac-video mac-zoom-contact"
        />
      </DeviceFrame>
      <div className="callout success">Signed capability contact</div>
    </Stage>
  );
};

const QuestionScene: React.FC = () => {
  return (
    <Stage
      eyebrow="PHYSICAL PROOF · 4"
      title="Ask one bounded question"
      detail="Non-sensitive inert text only · 1,200-character input limit"
    >
      <DeviceFrame kind="iphone" className="question-phone">
        <Video
          src={staticFile("raw/iphone.mp4")}
          trimBefore={1080}
          muted
          className="iphone-video"
        />
      </DeviceFrame>
      <DeviceFrame kind="mac" className="question-mac">
        <Video
          src={staticFile("raw/mac.mov")}
          trimBefore={1441}
          muted
          className="mac-video mac-zoom-model"
        />
      </DeviceFrame>
      <div className="callout neutral">Signed · expiring · session-bound</div>
    </Stage>
  );
};

const ModelScene: React.FC = () => {
  return (
    <Stage
      eyebrow="PHYSICAL PROOF · 5"
      title="A stronger model, inside a narrow boundary"
      detail="GPT-5.6 model-only XPC · no files · no shell · no workspace · no tools"
    >
      <DeviceFrame kind="mac" className="model-mac">
        <Video
          src={staticFile("raw/mac.mov")}
          trimBefore={1561}
          playbackRate={0.7142857143}
          muted
          className="mac-video mac-zoom-model"
        />
      </DeviceFrame>
      <DeviceFrame kind="iphone" className="model-phone">
        <Video
          src={staticFile("raw/iphone.mp4")}
          trimBefore={1200}
          playbackRate={0.7142857143}
          muted
          className="iphone-video"
        />
      </DeviceFrame>
      <div className="callout success">Host-controlled execution</div>
    </Stage>
  );
};

const AnswerScene: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <Stage
      eyebrow="PHYSICAL PROOF · 6"
      title="The signed answer returns to the iPhone"
      detail="Sender · session · expiry · signature · correlation"
    >
      <DeviceFrame kind="iphone" className="answer-phone">
        <Img
          src={staticFile("stills/iphone-answer.jpg")}
          className="answer-iphone-still"
          style={{
            scale: interpolate(frame, [0, 360], [1.02, 1.08], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        />
      </DeviceFrame>
      <DeviceFrame kind="mac" className="answer-mac">
        <Img src={staticFile("stills/mac-answer.jpg")} className="answer-mac-still" />
      </DeviceFrame>
      <div className="callout success">Verified before display</div>
    </Stage>
  );
};

const DiagnosticsScene: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <Stage
      eyebrow="PHYSICAL PROOF · 7"
      title="Correlated receipts, sanitized evidence"
      detail="Prompt, answer, credentials, and authorization values stay out of review exports."
    >
      <DeviceFrame kind="iphone">
        <Img
          src={staticFile("stills/iphone-diagnostics.jpg")}
          className="diagnostics-iphone-still"
          style={{
            scale: interpolate(frame, [0, 270], [1.01, 1.055], {
              extrapolateLeft: "clamp",
              extrapolateRight: "clamp",
            }),
          }}
        />
      </DeviceFrame>
      <DeviceFrame kind="mac">
        <Img src={staticFile("stills/mac-answer.jpg")} className="diagnostics-mac-still" />
      </DeviceFrame>
      <div className="callout neutral">Signed · correlated · acknowledged</div>
    </Stage>
  );
};

const ProofScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill className="proof-scene">
      <Img src={staticFile("cards/architecture-card.svg")} className="proof-card" />
      <div
        className="proof-strip"
        style={{
          opacity: interpolate(frame, [24, 44], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
          translate: `${interpolate(frame, [24, 44], [80, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })}px 0`,
        }}
      >
        <span>Built with Codex</span>
        <span>9 checkpoints</span>
        <span>54 tests</span>
        <span>real iPhone + Mac</span>
      </div>
    </AbsoluteFill>
  );
};

export const NearBridgeVideo: React.FC = () => {
  return (
    <AbsoluteFill className="video-root">
      <Sequence name="Holonia opening" durationInFrames={360}>
        <Card file="title-card.svg" label="Holonia opening" />
      </Sequence>
      <Sequence name="Holonia vision" from={360} durationInFrames={330}>
        <Card file="vision-card.svg" label="Holonia vision" />
      </Sequence>
      <Sequence name="Control model" from={690} durationInFrames={330}>
        <Card file="principle-card.svg" label="Holonia control model" />
      </Sequence>
      <Sequence name="NearBridge relationship" from={1020} durationInFrames={300}>
        <BrollRelationship />
      </Sequence>
      <Sequence name="Current platform and roadmap" from={1320} durationInFrames={660}>
        <Card file="platform-card.svg" label="NearBridge platform" />
      </Sequence>

      <Sequence name="Discovery" from={1980} durationInFrames={330}>
        <DiscoveryScene />
      </Sequence>
      <Sequence name="Pairing" from={2310} durationInFrames={390}>
        <PairingScene />
      </Sequence>
      <Sequence name="Capability contact" from={2700} durationInFrames={420}>
        <ContactScene />
      </Sequence>
      <Sequence name="Question" from={3120} durationInFrames={270}>
        <QuestionScene />
      </Sequence>
      <Sequence name="Model execution" from={3390} durationInFrames={630}>
        <ModelScene />
      </Sequence>
      <Sequence name="Answer" from={4020} durationInFrames={360}>
        <AnswerScene />
      </Sequence>
      <Sequence name="Receipts and diagnostics" from={4380} durationInFrames={270}>
        <DiagnosticsScene />
      </Sequence>

      <Sequence name="Engineering proof" from={4650} durationInFrames={330}>
        <ProofScene />
      </Sequence>
      <Sequence name="Final card" from={4980} durationInFrames={120}>
        <Card file="final-card.svg" label="NearBridge final card" />
      </Sequence>

      <Audio
        src={staticFile("audio/narration.wav")}
        playbackRate={0.884375}
        volume={(frame) =>
          interpolate(frame, [0, 18, 5040, 5099], [0, 1, 1, 0], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          })
        }
      />
      <NarrationCaptions />
    </AbsoluteFill>
  );
};
