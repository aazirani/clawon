# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-03-24

### Fixed

- **macOS crash on quit** — explicitly close the Drift/SQLite database via `didRequestAppExit()` before the Dart VM tears down, preventing a `SIGABRT` from SQLite's `functionDestroy` during process exit
- **Stale WebSocket timers on exit** — heartbeat monitors and reconnection timers are now cancelled during app shutdown, preventing potential crashes from timers firing after teardown

### Changed

- App Store metadata updated for guideline compliance (4.1c) — removed third-party brand name from app name, subtitle, description, and keywords

## [1.0.0] - 2026-02-22

### Added

- **Multi-gateway connections** — connect to multiple OpenClaw gateways simultaneously, each with its own session and message history
- **AI chat with streaming** — real-time streaming responses via OpenClaw Gateway Protocol v3, supporting both `agent` (text delta) and `chat` (full content block) event streams
- **Skills browser** — browse, enable/disable, and configure available skills on connected gateways
- **Agent creation assistant** — guided flow for creating and configuring custom AI agents
- **Session management** — view and manage active sessions across connections
- **Onboarding flow** — first-time setup screens to guide users through adding their first gateway connection
- **25-language support with RTL** — localisation for 25 languages including right-to-left support for Persian (fa), Arabic (ar), and Urdu (ur)
- **Message history persistence** — all messages stored locally via Drift (SQLite) with per-connection isolation

[1.0.1]: https://github.com/aazirani/clawon/releases/tag/v1.0.1
[1.0.0]: https://github.com/aazirani/clawon/releases/tag/v1.0.0
