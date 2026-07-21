# NearBridge YouTube and Devpost Copy

Replace only the bracketed fields before submission.

## YouTube

### Title

NearBridge — The First Working Edge of Holonia | OpenAI Build Week

### Description

Holonia is a capability discovery and work-connection network for people, Agents, and organizations. NearBridge is its first working implementation slice: a native iPhone + Mac experiment built with Codex and GPT-5.6 for OpenAI Build Week.

An iPhone discovers a user-launched Mac on the same local network, explicitly pairs with it, establishes a fresh authenticated session, and invokes one Mac-selected inert-text Primary Holon capability. The Mac calls a bounded GPT-5.6 model-only adapter and returns a signed, correlated result that the iPhone validates and displays.

Safety boundaries in this checkpoint:
- discovery is not authentication
- explicit approval on both devices
- API key remains in Mac Keychain
- fixed Responses API request with `store: false` and omitted tools
- no files, shell, workspace, Git, device control, dynamic tools, or background daemon
- sanitized diagnostics omit prompt/answer bodies and redact credentials

Repository: https://github.com/YizeSun/holonia
Checkpoint: `nearbridge-build-week-p0-p1`

This is an experimental Build Week checkpoint, not a production-security or payload-encryption claim. Model output can be wrong and should be verified before important use.

### Suggested visibility and settings

- Visibility: Public.
- Category: Science & Technology.
- Language: English.
- License: Standard YouTube License unless you intentionally choose otherwise.
- Audience: Not made for kids.
- Comments: optional.
- Do not add copyrighted music, third-party logos, or an unlicensed thumbnail asset.

## Devpost short description

NearBridge is the first working edge of Holonia: it lets an iPhone explicitly discover, authenticate, and ask a stronger model selected by a nearby Mac, then receive a signed and auditable answer without granting files, shell, workspace, or dynamic tools.

## Devpost inspiration

Holonia begins with a broader question: when a person or Agent lacks a capability, how can a request find the right Holon, establish trusted contact, delegate work, and receive a verifiable result? The phone in a person’s hand is not always the best place to run the strongest available model. At the same time, turning a personal Mac into a generic remote-execution server would create unacceptable risk. We started with NearBridge: a local foundation where discovery stays untrusted, people approve identity on both devices, and the Host—not a remote prompt—controls exactly what capability can run.

## Devpost what it does

NearBridge consists of native SwiftUI apps for iPhone and Mac. The apps discover one another over Bonjour and Network.framework, but discovery never establishes trust. The user compares and approves a six-digit pairing code on both devices. A fresh authenticated session then carries signed, expiring, replay-aware messages.

After a signed contact workflow, the iPhone can invoke one registered inert-text Primary Holon capability. The Mac explicitly selects the implementation. In the Build Week real-model path, a separate app-sandboxed XPC runner calls GPT-5.6 through the fixed OpenAI Responses API. The Mac signs the typed result, the iPhone validates it, and both sides retain a correlated execution receipt.

## Devpost how we built it

We used Codex as the engineering collaborator across the Build Week implementation: turning a security/design brief into incremental NB checkpoints; implementing native discovery, pairing, authenticated messaging, contact and capability state machines; creating versioned Holon manifests, a capability registry, and execution profiles; separating local and network model runners into XPC services; diagnosing physical-device Bonjour, Keychain, signing, bundle, and XPC failures; and creating the tests, runbooks, reviewer UI, and evidence export.

GPT-5.6 is the actual bounded model in the demonstrated product path. The Mac Host supplies the credential from Keychain and uses a fixed model-only request with `store: false`, omitted tools, bounded input/output, redirect rejection, and a privacy-preserving session safety identifier.

## Devpost challenges

The hardest part was not sending text between devices. It was preserving the boundary between discovering a nearby service and trusting an identity, then keeping every later workflow tied to a fresh authenticated session. Physical Apple-device testing also exposed real packaging and permission issues: Local Network authorization, Keychain access, signing, application XPC registration, and bidirectional connection ownership all required iterative diagnosis.

## Devpost accomplishments

- Real iPhone ↔ Mac discovery, explicit pairing, authentication, and signed bidirectional messaging.
- A complete signed contact and capability invocation workflow.
- A Mac-selected Primary Holon abstraction with versioned manifests and explicit execution profiles.
- Separate app-sandboxed model runners with no file, shell, workspace, Git, or dynamic tool interface.
- A real GPT-5.6 model-only answer returned to the iPhone and acknowledged across one physical device pair.
- Fifty-four passing shared tests, two successful app-target builds, correlated execution receipts, and sanitized reviewer diagnostics.

## Devpost what we learned

Local discovery is useful transport metadata, not identity. A model adapter also should not inherit authority merely because the model or process claims to be sandboxed; the Host must define the available interface, credential source, network profile, limits, and audit trail. Small, versioned checkpoints and explicit separation between automated, simulator, and physical evidence made real-device failures much easier to understand.

## Devpost what is next

The next platform checkpoint is signed third-party adapter admission with version compatibility and isolation verification. Later work can introduce a controlled read-only workspace broker and, only after explicit policy and approval layers exist, carefully bounded tool-using Agents. Multi-client concurrency, payload-encryption decisions, recovery, longer-running reliability, and broader adversarial testing remain intentionally deferred.

## Built with

Swift, SwiftUI, Network.framework, Bonjour, CryptoKit, Security/Keychain, XPC, OpenAI Responses API, GPT-5.6, Codex, XCTest.

## Required links

- Repository: https://github.com/YizeSun/holonia
- Public YouTube demo: `[VIDEO_URL]`
- Codex `/feedback` Session ID: `[CODEX_SESSION_ID]`

Before submitting, verify that the GitHub repository is public or shared with the required judging accounts, and that the YouTube link opens in a private browser window without login.
