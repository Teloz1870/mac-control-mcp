#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
install_dir=${MAC_CONTROL_INSTALL_DIR:-"$HOME/.local/bin"}
binary="$install_dir/mac-control-mcp"

cd "$project_dir"
swift build -c release
mkdir -p "$install_dir"
install -m 0755 ".build/release/mac-control-mcp" "$binary"

printf '%s\n' "Installed: $binary"
printf '%s\n' "Run: $binary doctor --prompt"
printf '\n%s\n' "Codex (~/.codex/config.toml):"
printf '[mcp_servers.mac_control]\ncommand = "%s"\n' "$binary"
printf '\n%s\n' "Generic MCP client:"
printf '{"mcpServers":{"mac-control":{"command":"%s"}}}\n' "$binary"
printf '\n%s\n' "This script does not change Gatekeeper or Accessibility settings."
