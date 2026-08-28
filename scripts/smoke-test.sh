#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary=${MAC_CONTROL_BINARY:-"$project_dir/.build/debug/mac-control-mcp"}

cd "$project_dir"
swift build
"$binary" doctor
"$binary" scan com.anysphere.sand >/dev/null

printf '%s\n' 'Read-only smoke checks passed.'
printf '%s\n' 'Prompt/widget mutation smoke tests are intentionally opt-in and must use a disposable bot and explicit host approval.'
