# tools

Small, focused developer tools, each in its own numbered folder with its own README, build and tests.

| # | Tool | What it does | Platform |
|---|------|--------------|----------|
| 01 | [`01_MedidorClaude`](./01_MedidorClaude) | Menu bar meter and status line for Claude Code: 5-hour window, weekly limit, per-session health and prompt-caching countdown. | macOS 14+ |

## Layout

GitHub has no folders for repositories, so this is a monorepo: one directory per tool, numbered in the order they were added. A tool never depends on another one.

```
tools/
├── LICENSE
├── README.md
└── 01_MedidorClaude/
```

## Adding a tool

1. Create `NN_ToolName/` with a `README.md` covering purpose, install, usage, limitations and tests.
2. Keep it self-contained: its own build, scripts and tests.
3. Add a row to the table above.

## License

[MIT](./LICENSE)
