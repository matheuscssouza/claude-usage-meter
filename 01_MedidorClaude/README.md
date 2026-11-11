# MedidorClaude

A native macOS menu bar app and a terminal status line that show how much of your Claude Code usage is left, how healthy each open session is, and whether the prompt cache is still warm.

> The interface text is in Brazilian Portuguese. A Portuguese version of this document is in [README.pt-BR.md](./README.pt-BR.md).

```
5h ██████░░░░ 62% ↻2h5m │ Sem ███░░░░░░░ 31% ↻2d7h │ Ctx 18% 180k/1.0M │ 🔥 ativo 42 min │ ● atenção
```

## Why

Claude Code enforces a rolling 5-hour window and a weekly limit, and long conversations get expensive as the context grows. Both are easy to lose track of with several sessions open. This tool keeps them visible and tells you when to start a fresh session.

## Features

- **Usage limits**: 5-hour window and weekly limit, each with percentage and time until reset.
- **One row per open session**: the app lists every running Claude Code session with its own context usage (`tokens used of window size`) and health.
- **Session health**: healthy, attention, heavy or new session, derived from the worst of the 5h window, the weekly limit and the session's context.
- **Prompt caching countdown**: how long the cached prompt prefix stays valid after the last activity.
- **Menu bar summary**: one colored dot per session plus the session count.
- **Terminal status line**: the same information, in the line above the input prompt.
- **Zero token cost**: nothing here calls a model or the network.

### Health levels

| Worst of 5h / week / context | State |
|---|---|
| below 50% | healthy |
| 50–79% | attention |
| 80–95% | heavy |
| 96% or more | start a new session |

### Prompt caching stages

Anthropic's prompt caching bills cached input at a fraction of the normal price, but the cache expires after a period of inactivity. Once it expires, the next turn reprocesses the whole conversation at full price.

| Time left | Shown |
|---|---|
| 60–31 min | 🔥 ativo N min |
| 30–10 min | 💨 esfriando N min |
| 10 min or less | 💀 acabando N min |
| expired | 💀 expirado |

## How it works

```
 Claude Code ──stdin JSON──▶ statusline.sh ──▶ terminal line
                                  │
                                  ▼
                     ~/.claude/medidor/
                       ├─ usage.json            latest payload (account-wide limits)
                       └─ sessions/<id>.json    latest payload per session
                                  ▲
 ~/.claude/sessions/<pid>.json ───┤  live-process registry kept by Claude Code
                                  │
                          MedidorClaude.app (polls every 3 s)
```

- Claude Code pipes a JSON payload to the status line command on every update. It carries `rate_limits`, `context_window`, `session_id`, `transcript_path` and more.
- `statusline.sh` renders the line and persists the payload atomically.
- The app decides which sessions are open by checking that the PIDs in Claude Code's own registry are alive, so an idle session is still listed. Health data comes from the persisted payloads.
- A `SessionEnd` hook deletes a session's file when it closes. The app also prunes files of dead sessions.

## Requirements

- macOS 14 or later
- Swift toolchain (Xcode or Command Line Tools)
- `jq`
- Claude Code

## Install

```bash
git clone https://github.com/matheuscssouza/tools.git
cd tools/01_MedidorClaude
scripts/install.sh              # add --login-item to start at login
```

The installer builds the app into `~/Applications/MedidorClaude.app`, copies the status line to `~/.claude/statusline.sh`, and merges `statusLine` plus a `SessionEnd` hook into `~/.claude/settings.json`. Existing settings are kept and a backup is written to `settings.json.bak`. Running it again is safe.

Quit the app with `⌘Q` while its panel is open. Remove everything with `scripts/uninstall.sh`.

## Configuration

| Setting | Where | Default |
|---|---|---|
| Prompt caching TTL | `TTL` in `statusline/statusline.sh` and `3600` in `App.swift` | 3600 s |
| Health thresholds | `col` and the health block in `statusline/statusline.sh`, `Saude` in `App.swift` | 50 / 80 / 96 |
| State directory | `MEDIDOR_STATE_DIR` | `~/.claude/medidor` |
| Status line refresh | `statusLine.refreshInterval` in `settings.json` | 60 s |

## Limitations

- The prompt caching countdown is an estimate. It assumes a 1-hour TTL counted from the transcript's last write. If your setup uses a 5-minute TTL, the countdown is optimistic.
- `rate_limits` is only present in the payload for some plans and Claude Code versions. Without it the app shows "Aguardando dados".
- The status line depends on Claude Code's payload format, which is not a stable public contract.
- The app is ad-hoc signed, not notarized. It is built locally by the installer, so Gatekeeper does not block it.
- Text is in Portuguese only.

## Development

```bash
swift build -c release --scratch-path "$(mktemp -d)"   # build outside synced folders
tests/statusline.test.sh                                # status line tests
```

Source layout:

```
Sources/MedidorClaude/App.swift   SwiftUI app: models, menu bar icon, panel
statusline/statusline.sh          status line renderer and state writer
scripts/                          install and uninstall
tests/                            black-box tests for the status line
Resources/Info.plist              bundle metadata (LSUIElement: no Dock icon)
```

Do not build inside iCloud Drive or Dropbox folders: their sync engines corrupt SwiftPM's module cache. The install script already builds in a temporary directory.

## Privacy

Everything stays on your machine. The tool reads Claude Code's local payload and writes only under `~/.claude/medidor/`. It makes no network calls and sends no telemetry.

## License

[MIT](../LICENSE)
