# mac-control-mcp

Fast, local macOS app automation for MCP clients. `mac-control-mcp` uses the macOS Accessibility API and semantic selectors instead of screenshots and screen coordinates. The preview ships with a generic AX core and a Grok Bot 0.29.x adapter.

> Preview: source builds are recommended. Preview binaries are ad-hoc signed, not Apple-notarized. Do not bypass Gatekeeper.

## What it exposes

- Generic tools for allowed apps: list, inspect, find, read, perform an exposed action, set a safe value, press a menu item, wait, scan and diff.
- Grok Bot tools: status, bots, open, conversation, prompt, question widgets and routines.
- Short-lived element handles. Every operation re-finds and fingerprints the element before acting.
- AXObserver-backed waiting and bounded tree traversal.
- Read-only Electron metadata discovery for ASAR entries, preload namespaces, URL schemes and RPC method names. Private coordinator RPC is never invoked.

The default allowlist contains only `com.anysphere.sand` (Grok Bot). Secure fields, passwords, cookies, tokens, wallet data and known secret filenames are redacted or blocked.

## Requirements

- macOS 13 or newer
- Swift 6
- Accessibility permission for the installed binary or the terminal/Codex process launching a source build
- Grok Bot 0.29.x for its specialized adapter

## Build and verify

```sh
swift build
./scripts/test.sh
.build/debug/mac-control-mcp doctor
.build/debug/mac-control-mcp scan com.anysphere.sand
```

`doctor --prompt` asks macOS to show the Accessibility permission prompt. `scan` writes a redacted snapshot under `~/Library/Application Support/mac-control-mcp/snapshots/`.

## Install

```sh
./scripts/install.sh
```

The script builds from source, installs idempotently to `~/.local/bin/mac-control-mcp`, and prints configuration snippets. It does not change Gatekeeper settings.

Codex host configuration (`~/.codex/config.toml` or trusted-project `.codex/config.toml`):

```toml
[mcp_servers.mac_control]
command = "/Users/YOU/.local/bin/mac-control-mcp"
```

The ChatGPT desktop app, Codex CLI and IDE extension share this host configuration. You can also add the same binary as a STDIO server in Settings → MCP servers. See the [official Codex MCP documentation](https://learn.chatgpt.com/docs/extend/mcp).

Other MCP clients use the same command with STDIO transport:

```json
{
  "mcpServers": {
    "mac-control": {
      "command": "/Users/YOU/.local/bin/mac-control-mcp"
    }
  }
}
```

## Configuration

Optional file: `~/Library/Application Support/mac-control-mcp/config.json`

```json
{
  "allowedBundleIDs": ["com.anysphere.sand"],
  "handleLifetimeSeconds": 30,
  "maximumScanDepth": 12,
  "maximumScanNodes": 2000
}
```

Adding a bundle id authorizes only Accessibility operations and capability scanning for that app. The MCP server has no shell, network, credential or arbitrary file-mutation tools.

## Safety model

Sending prompts, setting values, pressing controls and running routines change external state. MCP tool annotations and server instructions tell the host to apply its approval rules. Unknown Grok Bot versions fail closed, selector failures recommend a rescan, and there is no automatic coordinate fallback.

Actions are scoped to the widget they belong to: an answer is pressed inside the resolved question widget, and a routine control is found inside that routine's own row, so an identically labelled control elsewhere in the window is never pressed instead. Menu paths are matched component by component down the real menu hierarchy. When a text field exposes no `AXConfirm` action, the submit fallback posts a Return key event to the target process and refuses to do so unless that app is frontmost.

Read [SECURITY.md](SECURITY.md) before adding adapters. Architecture and extension details are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and [docs/ADAPTERS.md](docs/ADAPTERS.md).

## Status

`v0.1.0-preview` targets Grok Bot 0.29.x. The generic core is designed for compiled-in Slack, Discord, Cursor and other adapters later. Dynamic third-party loading is intentionally out of scope for v1.

## License

MIT © 2026 Teloz1870.
