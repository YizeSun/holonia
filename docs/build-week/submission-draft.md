# OpenAI Build Week Submission Draft

Status: content-complete draft with one-device-pair P0/P1 physical evidence; add the public repository URL, public YouTube URL, final screenshots, and final Codex Session ID before submission.

## Project name

NearBridge — Reach a stronger Mac Primary Holon from your iPhone

## Suggested track

Apps for Your Life

## One-line summary

NearBridge lets an iPhone securely discover, pair with, and ask an explicitly selected model on a nearby Mac, then receive a signed and auditable answer without giving that model files, shell, workspace, or dynamic tools.

## Problem

The phone in a person’s hand is not always the best place to run the strongest available model, while exposing a personal Mac as a generic remote-execution server would be unsafe. Existing “nearby device” discovery also does not prove identity, user approval, or what capability will run.

## Solution

NearBridge turns a user-launched Mac app into a narrow, policy-enforcing Host. An iPhone can discover the Host over Bonjour, but discovery stays untrusted. Both devices explicitly approve a verification code. A fresh authenticated session then carries signed, expiring, replay-aware messages. Only after a signed contact workflow can the iPhone invoke one compile-time registered inert-text capability. The Mac chooses the Primary Holon implementation and returns a signed typed result.

## OpenAI use

The real remote path uses GPT-5.6 through the OpenAI Responses API from a separate app-sandboxed XPC runner. The request is fixed to plain-text question answering, sets `store: false`, omits tools, limits input to 1,200 characters and output to 4,000 characters, rejects redirects, and includes a privacy-preserving safety identifier derived from the authenticated preview session. The API key is entered only in the Mac app and stored in the Mac Host Keychain; it is never sent to the iPhone, logged, exported, or committed.

## How Codex was used

Codex was the engineering collaborator across the complete Build Week implementation: converting a written security/design brief into NB checkpoints; implementing native Swift discovery, pairing, authenticated messages, contact and capability state machines; introducing manifest/registry/execution-profile abstractions; separating local and network XPC runners; diagnosing real-device Bonjour, bundle, entitlement, Keychain, and XPC registration failures; writing tests and runbooks; and preparing the review experience and evidence. The repository’s incremental NB commits and tags preserve that development trail.

Final Devpost step: run `/feedback` in the relevant Codex task and paste the returned Session ID here: `[CODEX_SESSION_ID]`.

## Technical implementation

- SwiftUI apps for iOS and macOS.
- Bonjour and Network.framework for local advertising, browsing, and a bidirectional TCP session.
- Host-managed stable keys, user-confirmed pairing, fresh-session binding, signed/expiring messages, correlation, acknowledgement, and duplicate handling.
- Versioned `HolonManifest`, capability registry, and explicit adapter execution profiles.
- Mac-selectable adapters: OpenAI model-only, Apple Foundation Models runner, Apple NaturalLanguage, and deterministic fallback.
- Separate app-sandboxed XPC runners so the adapter receives no file, command, workspace, or dynamic tool interface.
- Demo/Diagnostics split, readiness checklist, example prompts, execution receipt, and sanitized evidence export.

## Why it matters

NearBridge demonstrates a practical pattern for personal AI: the best model available on a person’s nearby hardware can help the device in their hand, while the Host—not the remote prompt—controls identity, capability, credentials, runtime, and audit. The same stable capability facade can later support signed third-party adapters without turning discovery into trust or a model into arbitrary remote execution.

## Safety and privacy

- Explicit human pairing approval on both devices.
- Discovery metadata is not authentication.
- No secrets in prompts; no payload-encryption claim in this checkpoint.
- API key stays in Mac Keychain.
- `store: false`, tools omitted, bounded input/output, privacy-preserving safety identifier.
- Prompt and answer bodies omitted from diagnostic export.
- Model output may be wrong and should be verified before important use.
- No files, shell, Git, workspace, arbitrary URL, dynamic tool, background daemon, or autonomous code modification.

## Testing evidence

- Shared unit tests cover message validation, pairing, workflow, capability routing, manifests/profiles, OpenAI request boundaries, readiness, receipt behavior, redaction, and safety identifiers.
- Both app targets are built with the macOS and generic iOS Device SDKs.
- The NB-9 real GPT-5.6 physical path was observed on one iPhone/Mac pair, including signed result display and acknowledgement.
- The Build Week P0/P1 review UI and correlated receipts were physically observed on one real iPhone/Mac pair; this does not claim the deferred error, longevity, network-switching, or multi-client matrices.

## Links to complete

- Public repository: `[REPOSITORY_URL]`
- Public YouTube demo (3 minutes or less, English narration or English translation): `[VIDEO_URL]`
- Codex Session ID: `[CODEX_SESSION_ID]`
- Optional project page/contact: `[OPTIONAL_URL]`
