# Claude Usage Meter

[![CI](https://github.com/matheuscssouza/claude-usage-meter/actions/workflows/ci.yml/badge.svg)](https://github.com/matheuscssouza/claude-usage-meter/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

A native macOS menu bar app and a terminal status line that show how much of your **Claude Code** usage is left, how healthy each open session is, and how long the prompt cache stays valid.

```
5h ██████░░░░ 62% ↻2h5m │ Wk ███░░░░░░░ 31% ↻2d7h │ Ctx 18% 180k/1.0M │ 🔥 active 42 min │ ● attention
```

## Why

Claude Code enforces a rolling 5-hour window and a weekly limit, and long conversations get more expensive as the context grows. With several sessions open it is easy to lose track of both. This tool keeps them visible and tells you when to start a fresh session.

## Features

- **Usage limits:** the 5-hour window and the weekly limit, each with its percentage and time until reset.
- **One row per open session:** every running Claude Code session with its own context usage (`tokens used of window size`) and health.
- **Session health:** healthy, attention, heavy or new session, from the worst of the 5-hour window, the weekly limit and the session's context.
- **Prompt caching countdown:** how long the cached prompt prefix stays valid after the last activity.
- **Menu bar summary:** one colored dot per session plus the session count.
- **Terminal status line:** the same information above Claude Code's input prompt.
- **Zero token cost:** nothing here calls a model or the network.

### Health levels

| Worst of 5h / week / context | State |
|---|---|
| below 50% | healthy |
| 50–79% | attention |
| 80–95% | heavy |
| 96% or more | start a new session |

### Prompt caching stages

Prompt caching bills cached input at a fraction of the normal price, but the cache expires after a period of inactivity. Once it does, the next turn reprocesses the whole conversation at full price.

| Time left | Shown |
|---|---|
| 60–31 min | 🔥 active N min |
| 30–10 min | 💨 cooling N min |
| 10 min or less | 💀 ending N min |
| expired | 💀 expired |

## How it works

```
 Claude Code ──stdin JSON──▶ statusline.sh ──▶ terminal line
                                  │
                                  ▼
                     ~/.claude/usage-meter/
                       ├─ usage.json            latest payload (account-wide limits)
                       └─ sessions/<id>.json    latest payload per session
                                  ▲
 ~/.claude/sessions/<pid>.json ───┤  live-process registry kept by Claude Code
                                  │
                       ClaudeUsageMeter.app (polls every 3 s)
```

- Claude Code pipes a JSON payload to the status line command on every update. It carries `rate_limits`, `context_window`, `session_id`, `transcript_path` and more.
- `statusline.sh` renders the line and persists the payload with atomic writes.
- The app decides which sessions are open by checking that the PIDs in Claude Code's own registry are alive, so an idle session is still listed. Health data comes from the persisted payloads.
- A `SessionEnd` hook deletes a session's file when it closes. The app also prunes files of dead sessions.

## Requirements

- macOS 14 or later
- Swift toolchain (Xcode or the Command Line Tools)
- `jq`
- Claude Code

## Install

```bash
git clone https://github.com/matheuscssouza/claude-usage-meter.git
cd claude-usage-meter
scripts/install.sh              # add --login-item to start at login
```

The installer builds the app into `~/Applications/ClaudeUsageMeter.app`, copies the status line to `~/.claude/statusline.sh`, and merges `statusLine` plus a `SessionEnd` hook into `~/.claude/settings.json`. Existing settings are kept, and a timestamped backup is written next to the file. Running it again is safe.

Quit the app with `⌘Q` while its panel is open. Remove everything with `scripts/uninstall.sh`.

## Configuration

| Setting | Where | Default |
|---|---|---|
| Prompt caching TTL | `TTL` in `statusline/statusline.sh`, `CacheState.ttl` in `Models.swift` | 3600 s |
| Health thresholds | `col` and the health block in `statusline/statusline.sh`, `Health` in `Models.swift` | 50 / 80 / 96 |
| Status line refresh | `statusLine.refreshInterval` in `settings.json` | 60 s |

## Limitations

- The prompt caching countdown is an estimate. It assumes a 1-hour TTL counted from the transcript's last write. With a 5-minute TTL the countdown is optimistic.
- `rate_limits` is only present in the payload for some plans and Claude Code versions. Without it the app shows "Waiting for data".
- The status line depends on Claude Code's payload format, which is not a stable public contract.
- The app is ad-hoc signed, not notarized. The installer builds it locally, so Gatekeeper does not block it.
- macOS only.

## Project structure

```
Sources/ClaudeUsageMeter/
├── App.swift             entry point: menu bar scene
├── Models.swift          payload types, Session, Health, CacheState
├── UsageStore.swift      reads state files, publishes to the UI
├── MenuBarIcon.swift     draws the menu bar item
└── Views.swift           UsageRing, SessionRow, UsagePanel
statusline/statusline.sh  renders the status line and writes state
scripts/                  install and uninstall
tests/                    black-box tests for the status line
Resources/Info.plist      bundle metadata (LSUIElement: no Dock icon)
```

## Development

```bash
tests/statusline.test.sh                                # status line tests
swift build -c release --scratch-path "$(mktemp -d)"    # build outside synced folders
```

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## Privacy

Everything stays on your machine. The tool reads Claude Code's local payload and writes only under `~/.claude/usage-meter/`. It makes no network calls and sends no telemetry.

## License

[MIT](./LICENSE)
