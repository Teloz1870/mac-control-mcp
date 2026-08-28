#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-"$project_dir/dist"}
temporary_dir=$(mktemp -d)
trap 'rm -rf "$temporary_dir"' EXIT INT TERM

cd "$project_dir"
swift build -c release --arch arm64
cp ".build/arm64-apple-macosx/release/mac-control-mcp" "$temporary_dir/arm64"
swift build -c release --arch x86_64
cp ".build/x86_64-apple-macosx/release/mac-control-mcp" "$temporary_dir/x86_64"

mkdir -p "$output_dir"
lipo -create "$temporary_dir/arm64" "$temporary_dir/x86_64" -output "$output_dir/mac-control-mcp"
codesign --force --sign - "$output_dir/mac-control-mcp"
shasum -a 256 "$output_dir/mac-control-mcp" > "$output_dir/mac-control-mcp.sha256"
printf '%s\n' "Built ad-hoc-signed preview binary at $output_dir/mac-control-mcp"
