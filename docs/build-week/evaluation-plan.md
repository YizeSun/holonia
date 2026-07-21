# NearBridge Build Week Evaluation Plan

This plan follows a small, reproducible eval set instead of relying on one successful demo. Automated cases run without a live OpenAI call; provider and Apple-network behavior remain separately labeled physical tests.

## Success criteria

1. A discovered stranger is never shown as authenticated.
2. Pairing cannot complete without local approval on both devices.
3. Accepted messages must match the paired sender, fresh session, expiry, signature, and correlation rules.
4. Only the registered inert-text capability can execute.
5. The Mac-selected adapter, not the iPhone prompt, determines the runtime and network profile.
6. A result from an ended or mismatched session is rejected or discarded.
7. OpenAI requests use the fixed HTTPS endpoint/model, `store: false`, omitted tools, bounded tokens, no credential in the body, and a safety identifier.
8. Review evidence contains enough state to reproduce the path without exposing credentials or prompt/answer bodies.

## Automated set

| Case | Expected result | Current coverage |
| --- | --- | --- |
| Signed ping/pong/ack | Valid correlated round trip | Unit test |
| Wrong sender/session | Rejected | Unit test |
| Expired/future message | Rejected | Unit test |
| Tampered payload | Signature rejection | Unit test |
| Duplicate message | Ignored without duplicate execution | Unit test |
| Contact steps out of order | State transition rejected | Unit test |
| Unknown capability | Host rejects | Unit test |
| Oversized input/output | Host/runner rejects | Unit test |
| OpenAI redirect/status failure | Bounded local error | Unit test with stub transport |
| Diagnostic credential patterns | Redacted | Unit test |
| Readiness complete/incomplete | Correct next action | Unit test |
| Execution receipt | Outcome/ack/latency retained | Unit test |

## Physical reviewer set

| Case | Classification before run | Pass evidence |
| --- | --- | --- |
| Build Week P0/P1 Demo view on iPhone and Mac | Passed on one real device pair | Both layouts reported 5/5 readiness ready and exposed correlated receipts |
| Same-Wi-Fi discovery | Previously observed at NB-9 | Both nodes appear without being marked trusted |
| Fresh pairing | Previously observed at NB-9 | Matching code, authenticated state on both sides |
| OpenAI real answer | Previously observed at NB-9 | iPhone answer, Mac signed result, iPhone acknowledgement |
| Build Week P0/P1 execution receipt | Passed on one real device pair | Same invocation/capability; iPhone acknowledgement sent and Mac received |
| Sanitized export | Passed on both real-device roles | Shareable text contained no prompt, answer, API key, or Authorization value |
| Invalid key | Not tested | Clear failure, no credential/provider body leak, retry available |
| Wi-Fi unavailable | Not tested | Actionable discovery/error state, no false authentication |

## Quality review prompts

Use at least three ordinary, non-sensitive prompts with a checkable answer shape:

1. “Explain in three short sentences why the sky appears blue during the day.”
2. “Give me three practical ways to focus for twenty minutes without using personal data.”
3. “Compare local and cloud AI in four concise bullet points.”

Score each result on instruction following (0/1), factual plausibility (0/1), requested format (0/1), absence of unsupported tool/file claims (0/1), and successful signed delivery (0/1). Keep provider answer quality separate from NearBridge transport/authentication correctness.

## Deferred adversarial set

- Prompt injection asking for files, shell, hidden instructions, API keys, or tools.
- Repeated taps and duplicate network delivery.
- Disconnect during model execution.
- Invalid/missing key, 401/403, 429, provider 5xx, and offline runner.
- Second iPhone stored as a distinct trust record and used sequentially.
- Background/foreground, lock/unlock, Mac sleep, network switch, and app restart.

These remain TODO until observed; they must not be represented as passed based on code inspection alone.
