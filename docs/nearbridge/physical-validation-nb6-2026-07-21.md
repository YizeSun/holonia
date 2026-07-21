# NearBridge NB-6 physical validation — 2026-07-21

## Classification

**Core Primary Holon real-model path observed successfully on a physical iPhone and Mac; persistence, adapter-switching, failure and stability matrices remain open.**

## Tested revision

- Current NearBridge checkpoint: `7168e8a` (`NB-6: add Primary Holon adapters`).
- Both screenshots identify the running applications as `NearBridge NB-6` and were captured after that checkpoint was built.
- The screenshots do not independently attest the executable hash; the revision classification also relies on the local workspace being at `7168e8a` for this run.

## Environment

- Physical Mac running the NearBridge Mac app.
- Physical iPhone running the NearBridge iOS app.
- Simulator was not used.
- The exact OS builds, cable state and router details were not captured again in the NB-6 screenshots. The earlier same-day device-pair environment is recorded separately in [`physical-validation-2026-07-21.md`](physical-validation-2026-07-21.md), but is not silently copied into this run's claims.

## Observed results

| Layer | Physical observation |
| --- | --- |
| Primary Holon selection | The Mac showed `Apple Natural Language`, `AppleNaturalLanguageHolonAdapter`, runtime `appleNaturalLanguage`, and `Real model: yes · on-device`. |
| Discovery and authentication prerequisite | The Mac discovered the physical iPhone, paired with the stored iPhone fingerprint, and the later signed workflow/capability exchange ran over the physical session. |
| Contact workflow | The iPhone and Mac both reached `Contact flow completed`. |
| Host policy and adapter routing | The Mac showed only `holonia.capability.primary-holon.text-insight.v1`, executor `AppleNaturalLanguageHolonAdapter (on-device model)`, input ≤ 1,200 and output ≤ 280. |
| Real-model execution | Both devices showed `Execution: succeeded` and the same result: `Apple on-device model · language: en (99%) · sentiment: negative (-0.60)`. |
| Signed result path | Mac diagnostics showed `capability.resultSent` for `capabilityResult · holonia.capability.primary-holon.text-insight.v1` with message `1726B56D-9C05-44F3-86CE-388880D0B068`, followed by signed acknowledgement events. The iPhone displayed the returned result. |

The sentiment classification is model output, not a NearBridge authorization or trust decision. Its semantic quality is outside this transport/capability checkpoint.

## User-supplied visual evidence

The Codex task supplied and reviewed:

- `Screenshot 2026-07-21 at 15.41.49.png`: Mac Primary Holon selection, real-model disclosure, discovery and untrusted iPhone peer.
- `截屏 2026-07-21 15.43.34.png`: iPhone completed Contact state and successful Apple on-device model result.
- `Screenshot 2026-07-21 at 15.44.37.png`: Mac selected capability, successful execution, identical result, paired iPhone and signed result/acknowledgement diagnostics.

The screenshots were reviewed in the task but are not copied into this repository.

## Still deferred

- Quit/relaunch persistence of the selected implementation.
- Selection lock while connected.
- Switch to `Deterministic summary demo`, reconnect and verify adapter replacement.
- Empty/oversized/command-like/repeated input physical cases.
- Disconnect/reconnect, Wi-Fi switching, sleep/wake and longer-running stability.
- Runtime network observation supporting the no-cloud claim.
- Payload encryption, third-party process sandbox, Primary Holon Account binding, Codex or generative-model adapters.

These remain explicitly untested in [`deferred-validation-todo.md`](deferred-validation-todo.md). This run supports the narrow claim that the NB-6 Apple NaturalLanguage Primary Holon path executed end-to-end on one physical Mac/iPhone pair; it does not establish production readiness.
