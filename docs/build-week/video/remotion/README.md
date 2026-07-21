# NearBridge Build Week video edit

This is the editable Remotion project for the 2:50 NearBridge demo video. It
combines the real iPhone and Mac recordings with the approved Holonia story
cards, English narration, captions, and evidence stills.

## Source placement

The raw recordings are intentionally ignored by Git. Place local copies here:

- `public/raw/iphone.mp4`
- `public/raw/mac.mov`

The supplied Mac recording is 12.04 seconds longer than the iPhone recording.
The timeline trims **361 frames at 30 fps (12.03 seconds) from the beginning of
the Mac recording**, so the matching endings stay aligned. Do not trim the end
of either source when replacing these two files with the same takes.

The generated narration is also local-only:

- `public/audio/narration.wav`

Cards, captions, and evidence stills in `public/cards`, `public/captions`, and
`public/stills` are tracked sources.

## Edit structure

The composition is `NearBridgeBuildWeek`, 1920×1080 at 30 fps for 5,100 frames
(2:50). Its narrative order is:

1. Holonia vision and Host-enforced boundary.
2. NearBridge as Holonia's first working edge.
3. Implemented platform interfaces versus future work.
4. Physical discovery, pairing, authenticated contact, and iPhone question.
5. Mac model-only execution and the signed answer returned to iPhone.
6. Correlated diagnostics, engineering proof, and the next roadmap layers.

## Commands

```console
npm install
npm run lint
npm run dev
npm run render
```

The final render is written to `out/nearbridge-build-week.mp4`. For a faster
half-resolution proof render:

```console
npx remotion render NearBridgeBuildWeek out/nearbridge-build-week-draft.mp4 \
  --codec=h264 --audio-codec=aac --crf=23 --pixel-format=yuv420p \
  --scale=0.5 --concurrency=1
```

The `out` directory is ignored by Git. Rendering at concurrency 1 is deliberate:
the iPhone recording requires Remotion's frame extraction fallback, and the
lower concurrency is more reliable for the complete 170-second composition.

## Replacing the generated voice

The current WAV is a timing reference generated from `../narration-en.txt`.
Replace it with a human or preferred AI voice while preserving approximately
the same 170-second delivery. Captions come from
`../captions-en.srt`; update both sources together if wording changes.

## Review constraints

- Never expose credentials or sensitive prompt content.
- Discovery is not authentication.
- The current demo does not claim payload encryption or production readiness.
- Keep `NOW`, `NEXT`, and `LATER` visually distinct.
- Use only the real-device footage for the discovery, pairing, and model path.
