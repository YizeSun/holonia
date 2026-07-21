# NearBridge Validation Evidence

Last updated: 2026-07-22

NearBridge has completed one end-to-end physical-device path on a real iPhone
and Mac. This page separates automated, build, and physical evidence so that a
successful demo is not mistaken for broader production readiness.

## Evidence labels

- **Automated** means the shared Swift tests ran in the local development
  environment.
- **Build** means the named Xcode target compiled for the stated destination.
- **Physical** means behavior was observed on a real iPhone and Mac.
- **Not run** means no claim is made from source inspection or compilation
  alone.

## Current review snapshot

| Evidence | Result |
| --- | --- |
| Shared Swift tests | 54/54 passed |
| macOS target | Built successfully |
| Generic iOS Device target | Built successfully |
| Mac application bundle | Embedded `NearBridgeModelRunner.xpc` and `NearBridgeOpenAIRunner.xpc` |
| Simulator runtime | Not run |
| Physical devices | One real iPhone/Mac pair completed the review path |
| Public demonstration | [2:50 physical-device video](https://youtu.be/4s-6gypJUYA) |

## Checkpoint ledger

| Checkpoint | Delivered boundary | Automated and build evidence | Physical evidence |
| --- | --- | --- | --- |
| NB-0 | Local discovery, experimental bidirectional session, ping/pong, diagnostics | Passed | Core Wi-Fi path passed |
| NB-1 | Integrated discovery behavior | 11/11 tests; macOS and iOS Device builds passed | Bidirectional discovery observed; extended lifecycle matrix pending |
| NB-2 | Explicit pairing, stable Host identity, revocable trust record | 16/16 tests; both builds passed | Integrated pairing/authentication path passed; restart and revocation matrix pending |
| NB-3 | Fresh-session authentication, signed/expiring/replay-aware messages | 20/20 tests; both builds passed | Signed integrated messages observed; dedicated disconnect/reconnect matrix pending |
| NB-4 | Signed capability-contact workflow | 23/23 tests; both builds passed | Complete contact path passed |
| NB-5 | Host-registered deterministic text capability | 27/27 tests; both builds passed | iPhone invocation, Mac execution, and signed result passed |
| NB-6 | Primary Holon selection and Apple Natural Language adapter | 32/32 tests; both builds passed | Apple on-device model path passed |
| NB-7 | Versioned `HolonManifest`, capability registry, execution profiles | 37/37 tests; both builds passed | Not run at this checkpoint |
| NB-8 | App-sandboxed local-model XPC runner and bounded execution contract | 39/39 tests; both builds and XPC embedding passed | Not run at this checkpoint |
| NB-9 | OpenAI model-only adapter, Keychain credential boundary, network-client XPC runner | 50/50 tests; both builds and dual-XPC embedding passed | Real iPhone → Mac → model → signed result → acknowledgement path passed |
| Build Week P0/P1 | Reviewer UI, readiness, execution receipts, sanitized export, safety identifier | 54/54 tests; both builds and dual-XPC embedding passed | Review path and correlated evidence passed on the same real device pair |

## Observed physical path

On 2026-07-21, one real iPhone and Mac completed the following sequence:

1. both user-launched apps discovered one another on the same Wi-Fi;
2. both devices approved the same six-digit pairing code;
3. the peers established a fresh authenticated session;
4. the iPhone completed the signed Primary Holon contact workflow;
5. the iPhone submitted an ordinary non-sensitive question;
6. the Mac Host admitted the registered capability and invoked its explicitly
   selected OpenAI model-only adapter;
7. the bounded answer returned as a signed typed result;
8. the iPhone validated and displayed the answer, then acknowledged it; and
9. both devices showed correlated execution receipts, while sanitized exports
   excluded prompt text, answer text, credentials, and authorization values.

## What this evidence does not claim

- No simulator runtime result is claimed.
- Physical coverage currently represents one device pair, not concurrent
  multi-client routing or automatic answerer selection.
- Network switching, long-running stability, comprehensive provider failures,
  repeated execution, revocation/recovery, and lifecycle matrices remain
  incomplete.
- NearBridge does not claim end-to-end payload encryption; the review path is
  limited to non-sensitive text.
- No capability receives file, workspace, shell, Git, device-control, arbitrary
  URL, dynamic-tool, or persistent Agent authority.
- The current result is an experimental checkpoint, not a production-readiness
  claim.

## Reproduce or inspect

- Follow the [three-minute reviewer runbook](reviewer-runbook.md).
- Review the [evaluation plan](evaluation-plan.md) for success and failure
  criteria.
- Run the shared tests:

```bash
cd NearBridge
swift test
```
