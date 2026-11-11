# Contributing

Thanks for taking an interest. The project is small, so the process is too.

## Setup

```bash
git clone https://github.com/matheuscssouza/claude-usage-meter.git
cd claude-usage-meter
tests/statusline.test.sh                              # status line tests
swift build -c release --scratch-path "$(mktemp -d)"  # build the app
```

Build outside iCloud Drive and Dropbox folders: their sync engines corrupt SwiftPM's module cache.

## Pull requests

- Open an issue first for anything bigger than a small fix.
- Keep one concern per pull request.
- Run the tests before pushing. CI runs the same ones plus a release build.
- Behavior of the status line must be covered by a case in `tests/statusline.test.sh`.

## Code style

- Swift: one type per responsibility, no force unwraps, optionals handled explicitly.
- Shell: `bash`, quote every expansion, no dependencies beyond `jq` and macOS built-ins.
- User-facing text is in English.

## Reporting bugs

Include your macOS version, Claude Code version and the output of the status line for a session that misbehaves.
