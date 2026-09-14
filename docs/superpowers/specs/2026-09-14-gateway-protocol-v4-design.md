# Gateway Protocol v4 Support — Design

Date: 2026-09-14
Issue: https://github.com/aazirani/clawon/issues/1
Status: Approved

## Problem

ClawOn 1.0.1 cannot connect to OpenClaw gateways >= 2026.6.8. Users see a raw
"protocol mismatch" error immediately on connect.

## Root Cause

ClawOn pins its protocol range to v3 in the WebSocket connect handshake
(`lib/data/datasources/openclaw_ws_datasource.dart:173-174` sends
`minProtocol: 3, maxProtocol: 3`). Gateways since 2026.6.8 enforce
`MIN_CLIENT_PROTOCOL_VERSION = 4` (openclaw
`packages/gateway-protocol/src/version.ts`, enforced in
`src/gateway/server/ws-connection/connect-admission.ts:239-252`): a client is
admitted only if `client.maxProtocol >= 4 && client.minProtocol <= 4`. With
`maxProtocol: 3`, ClawOn is rejected with a `PROTOCOL_MISMATCH` error and
WebSocket close 1002.

Upstream did not add the `gateway.minClientProtocol` escape hatch requested in
issue #1 — the floor is hard-coded. The fix belongs in ClawOn.

Beyond admission, protocol v4 changes the wire surface ClawOn depends on:

1. **Streaming replies** move from `agent` events (`payload.stream`,
   `payload.data.text`) to `chat` events — a discriminated union on `state`:
   `status | delta | final | aborted | error`. Delta frames require
   `deltaText` (incremental text); non-prefix replacements set `replace: true`
   with `deltaText` as the full replacement; `message` remains a cumulative
   snapshot (openclaw `packages/gateway-protocol/src/schema/logs-chat.ts:299-436`).
2. **`chat.send`** requires an `idempotencyKey` parameter
   (`ChatSendParamsSchema`, logs-chat.ts:245-280).
3. **`chat.history`** result shape changed to a cursor result
   `{kind: "delta" | "reset", messages: [...], deltaCursor, sessionInfo}`
   (logs-chat.ts:116-138) — no legacy `payloads[]` array.

## Goals

- ClawOn connects to gateways enforcing protocol v4 (>= 2026.6.8).
- ClawOn keeps working against older v3-only gateways (< 2026.6.8).
- Protocol mismatches surface a human-readable error instead of a raw failure
  (the UX ask in issue #1).

## Non-Goals

- `message.action` RPC support (ClawOn's delete/resend actions are local-only).
- UI for `chat` `status` events (retry indicators).
- New gateway client IDs (existing whitelisted `openclaw-*` IDs remain valid
  at openclaw HEAD; the registry is closed and `clawon` is not a member).
- Any change to pairing/HMAC device auth (unchanged in v4).

## Design

### 1. Protocol negotiation (datasource)

`OpenClawWebSocketDatasource.connect()` sends `minProtocol: 3,
maxProtocol: 4`. Both gateway generations admit overlapping ranges:

- v4 gateway (protocol 4): `max 4 >= 4 && min 3 <= 4` — admitted as v4.
- v3 gateway (protocol 3): `max 4 >= 3 && min 3 <= 3` — admitted as v3.

On `hello-ok`, read `payload.protocol` (3 or 4) and expose it as
`negotiatedProtocol` so repositories can select the correct parsing path.
Device-token rotation from `payload.auth.deviceToken` is unchanged.

### 2. Streaming dual-path (chat repository)

- Protocol 3: existing `agent`-event handling stays byte-identical.
- Protocol 4: handle `chat` events:
  - `state: "delta"` — accumulate `deltaText` per `runId`; on `replace: true`
    reset the accumulator to `deltaText`; when the cumulative `message`
    snapshot carries text, prefer it (matches the existing
    full-replacement update model in `StreamingResponseHandler`).
  - `state: "final"` — finalize the streaming message.
  - `state: "aborted" | "error"` — finalize and surface `errorMessage` /
    `errorKind`.
  - `state: "status"` — ignored.
- Session-registry ownership gating (`sessionKey` / `runId`) applies to both
  paths. The `agent`-event listener stays active in both protocols for
  lifecycle events.

### 3. RPC adaptation

- `chat.send`: include an `idempotencyKey` (UUID v4) when the negotiated
  protocol is 4; omit it on v3 (older gateways validate closed schemas and an
  unknown field risks rejection). Verify the v4 response shape against
  `ChatSendParamsSchema` / result schemas during implementation and adapt the
  `payloads[0].text` final-response parsing if needed.
- `chat.history`: dual-path result mapping keyed on `negotiatedProtocol` —
  legacy parsing for v3; `{kind, messages[], deltaCursor}` mapping for v4
  (treat `kind: "reset"` as full-history refresh, `kind: "delta"` as
  incremental). Exact v4 message item schema to be confirmed from openclaw
  `logs-chat.ts` during implementation.
- All other RPC methods ClawOn uses (`agents.list`, `sessions.list`,
  `sessions.patch`, `sessions.delete`, `skills.status`, `skills.update`,
  `skills.install`) verified present and unchanged at openclaw HEAD.

### 4. Error UX

Map WebSocket close 1002 and response errors with
`details.code == "PROTOCOL_MISMATCH"` to a readable message, e.g.
"Gateway requires protocol v4 — update ClawOn or upgrade your gateway."
The error includes the gateway's `expectedProtocol` when present so a future
v5 floor produces an accurate message.

### 5. Testing

New fake-WebSocket datasource tests (none exist today):

- Connect frame carries `minProtocol: 3, maxProtocol: 4` and completes the
  challenge/HMAC handshake.
- `hello-ok` protocol capture (3 and 4) and device-token rotation.
- Mismatch (close 1002 / PROTOCOL_MISMATCH error) produces the readable
  error state.

Repository tests:

- v4 delta accumulation: incremental deltas, `replace: true`, `final`,
  `error` frames.
- v3 regression: `agent`-event streaming still works end to end.
- `chat.send` includes `idempotencyKey` only on protocol 4.
- `chat.history` v4 cursor-result mapping.

Verification before completion: `flutter analyze` clean and `flutter test`
green after `build_runner` codegen.

## Release

- `pubspec.yaml`: version `1.1.0+11`.
- `CHANGELOG.md`: 1.1.0 entry — Gateway Protocol v4 support, fixes #1, keeps
  v3 compatibility, readable protocol-mismatch errors.
- Tag `v1.1.0` triggers the existing `build.yml` workflow, which builds all
  platforms and publishes the GitHub Release with artifacts. Store
  submissions remain manual.

## References

- openclaw HEAD: `packages/gateway-protocol/src/version.ts`,
  `connect-admission.ts:239-274`, `schema/logs-chat.ts`,
  `schema/agent.ts`, `docs/gateway/protocol/handshake.md`.
- Issue #1 report: gateway 2026.6.8, `minProtocol: 4` enforcement,
  ClawOn "protocol mismatch" on connect.
