#!/bin/sh
# Build, verify, install and publish in one step.
#
#   ./scripts/ship.sh "commit message"              stages the whole working tree
#   ./scripts/ship.sh "commit message" path...      stages only those paths
#
# Stops at the first failure, so a red build never reaches the binary you are about
# to run or the branch anyone else is reading.
set -eu

if [ $# -lt 1 ]; then
    printf '%s\n' 'usage: ./scripts/ship.sh "commit message"' >&2
    exit 2
fi

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

printf '\n=== build ===\n'
swift build

printf '\n=== test ===\n'
./scripts/test.sh

printf '\n=== security ===\n'
./scripts/security-check.sh

printf '\n=== install ===\n'
./scripts/install.sh >/dev/null
# A stable identifier gives macOS something to keep the Accessibility grant against.
# Without it every rebuild is a new identity and the permission drops silently.
codesign --force --sign - --identifier dk.hegnsfabrikken.mac-control-mcp \
    "$HOME/.local/bin/mac-control-mcp"
printf 'installed: %s (%s)\n' \
    "$HOME/.local/bin/mac-control-mcp" \
    "$("$HOME/.local/bin/mac-control-mcp" version)"

printf '\n=== publish ===\n'
# Staging everything is how another lane's work gets swept into your commit and pushed
# in the same step, which PROTOCOL.md §2 exists to prevent. The set is printed before
# it is staged, so a sweep is at least never silent; pass explicit paths after the
# message to stage only those.
if [ -n "$(git status --porcelain)" ]; then
    shift
    if [ $# -gt 0 ]; then
        printf 'staging named paths only:\n'
        for path in "$@"; do printf '  %s\n' "$path"; done
        git add -- "$@"
    else
        printf 'staging every change in the working tree:\n'
        git status --short | sed 's/^/  /'
        printf 'If any of that belongs to another lane, stop now and stage by path instead.\n'
        git add -A
    fi
    git commit -m "$1"
else
    printf 'nothing to commit\n'
fi
git pull --rebase --quiet origin main
git push --quiet
printf 'pushed: %s\n' "$(git rev-parse --short HEAD)"

printf '\n=== next ===\n'
printf 'Restart Claude (Cmd+Q, reopen) so the MCP server picks up this binary.\n'
printf 'If tools report "Accessibility permission is not granted", remove and re-add\n'
printf '  %s\n' "$HOME/.local/bin/mac-control-mcp"
printf 'in System Settings > Privacy & Security > Accessibility.\n'
