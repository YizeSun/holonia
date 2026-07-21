# NearBridge integrated physical validation — 2026-07-21

## Classification

**NB-1 through NB-6 and NB-9 core physical paths observed successfully; deferred physical matrices remain open.**

The morning run validated the NB-1 through NB-5 main vertical path. Later runs validated the NB-6 Apple NaturalLanguage Primary Holon path and the NB-9 OpenAI model-only answer path on the same physical device class. This record does not claim that every historical checkpoint commit was installed separately, nor that every failure, restart, revocation, multi-device, or boundary case was exercised.

## Tested revision

- NearBridge implementation base: `68ee156d29d64b38d98fb0827739af92bfae709d` (`Harden NearBridge trust persistence`).
- The Mac target required an Apple development identity before macOS would reliably grant local-network privacy access. The tested workspace added `DEVELOPMENT_TEAM = ZMN7LG4SD9` to both Mac configurations; that exact source state is captured by follow-up commit `2c76865` (`Configure NearBridge Mac development signing`).
- The successful Mac bundle reported `TeamIdentifier=ZMN7LG4SD9`; the earlier ad-hoc build reported `NoAuth (-65555)` for both Bonjour browser and listener.
- No NearBridge protocol or capability logic changed between `68ee156` and `2c76865`.
- The successful NB-9 Mac bundle included the XPC registration repair in `ef28df6` (`Fix embedded XPC service registration`); the iPhone used the compatible NB-9 message schema.

## Environment

- Mac mini running macOS 26.5.1 (25F80).
- Physical iPhone (`iPhone15,3`) running iOS 26.5.2 (23F84).
- Xcode 26.5 (17F42).
- Both user-launched apps were on the same ordinary Wi-Fi with the iPhone data cable disconnected during discovery, pairing, workflow, and capability execution.
- Simulator was not used.

## Observed results

| Layer | Physical observation |
| --- | --- |
| NB-1 discovery | Both apps advertised and discovered the other device. The Mac showed `NearBridge-iPhone`; the iPhone showed `NearBridge-mac`; discovery reached `peerDiscovered`. Discovery remained explicitly untrusted before pairing. |
| NB-2 pairing | Both sides displayed the same six-digit verification code, required local approval, reached `established`, and displayed paired records with the expected peer fingerprints. Keychain write succeeded during this run. |
| NB-3 authenticated messages | Both sides displayed `Authentication: authenticated`. Signed, session-bound Contact and capability messages plus acknowledgements crossed the physical connection with message UUIDs. The dedicated bidirectional signed ping/pong/disconnect matrix was not run. |
| NB-4 Contact workflow | The iPhone request, Mac capability response, iPhone acceptance, and Mac completion sequence reached `Contact flow completed` on both devices. Diagnostics showed signed workflow transitions and acknowledgements. |
| NB-5 capability | The iPhone invoked `holonia.capability.text-summary.extractive.v1`; the Mac `LocalSummaryAgent (deterministic demo)` reached `Execution: succeeded`, emitted signed `capabilityResult` and acknowledgement events, and the iPhone displayed the expected first-two-sentence summary with `Execution: succeeded`. |
| NB-6 Primary Holon | The Mac selected `AppleNaturalLanguageHolonAdapter`; the iPhone invoked the stable text-insight capability, both sides displayed the same real on-device language/sentiment result, and the signed result was acknowledged. |
| NB-9 OpenAI model-only | The iPhone submitted a non-sensitive sky-color question; the isolated Mac runner returned a three-sentence answer, both sides displayed `Execution: succeeded`, the Mac sent a signed `capabilityResult`, and the iPhone acknowledged it. |

The successful capability result began:

```text
NearBridge lets an iPhone discover and pair with a Mac. The Mac Host exposes only registered capabilities
```

## User-supplied visual evidence

The physical run supplied paired Mac/iPhone screenshots in the Codex task, including:

- `Screenshot 2026-07-21 at 11.44.56.png`: Mac discovery, connected/authenticated pairing, and completed Contact state.
- `Screenshot 2026-07-21 at 11.45.07.png`: Mac signed Contact workflow diagnostics.
- `截屏 2026-07-21 11.45.14.png`: iPhone paired state and completed Contact state.
- `Screenshot 2026-07-21 at 11.48.06.png`: Mac capability execution succeeded, signed result sent, and acknowledgement diagnostics.
- `截屏 2026-07-21 11.48.11.png`: iPhone capability execution succeeded and returned summary.
- `截屏 2026-07-21 15.43.34.png` and `Screenshot 2026-07-21 at 15.44.37.png`: NB-6 iPhone/Mac on-device Primary Holon result.
- `截屏 2026-07-21 17.47.24.png`: NB-9 iPhone execution succeeded and displayed the OpenAI model-only answer.
- `Screenshot 2026-07-21 at 17.47.39.png`: NB-9 Mac execution succeeded, sent `capabilityResult`, and received acknowledgement.

The screenshots were reviewed in the task but are not copied into this repository.

## Still deferred

- NB-1 peer-lost/restart/dedup matrix.
- NB-2 app-restart identity persistence, fresh-proof reconnect, revoke, and re-pair matrix.
- NB-3 dedicated signed ping/pong/ack in both directions, disconnect reset, and reconnect session-ID change.
- NB-4 disconnect reset and invalid-order/correlation physical injection.
- NB-5 command-like inert-text case, 1,201-character rejection, repeated invocation, and failure-path UI.
- NB-9 missing/invalid credential, offline, 401/403, 429, provider failure, repeated invocation, latency/usage, session-loss, and credential-removal matrix.
- Multiple simultaneous iPhones, queueing, routing, load balancing, and fairness. The current implementation intentionally permits only one active authenticated session and one in-flight Primary Holon invocation.
- Network switching, sleep/wake, long-running stability, payload encryption, and wider security review.

These remain non-blocking follow-up work in [`deferred-validation-todo.md`](deferred-validation-todo.md). This run supports the narrow claim that the final integrated NearBridge v0 vertical slice was observed on one Mac/iPhone pair and one Wi-Fi environment; it does not establish production readiness.
