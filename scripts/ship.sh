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

message="$1"
shift

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

printf '\n=== build ===\n'
swift build

printf '\n=== test ===\n'
./scripts/test.sh

printf '\n=== security ===\n'
./scripts/security-check.sh

printf '\n=== install ===\n'
binary="$HOME/.local/bin/mac-control-mcp"

# Replacing the binary costs an Accessibility re-grant, so it is only replaced when it
# actually differs. A round that only touches reports or documentation leaves the
# installed binary — and its permission — alone.
built=$(swift build -c release --show-bin-path)/mac-control-mcp
if [ -f "$binary" ] && cmp -s "$built" "$binary"; then
    installed_same=1
else
    installed_same=0
fi

# macOS binds the Accessibility grant to the code signature. A Developer ID is a stable
# identity, so the grant survives a rebuild; an ad-hoc signature is not, and re-granting
# after every install is the price. Measured over a day of reinstalls, the ad-hoc
# identifier below did not reliably keep the grant — it is a fallback, not a fix.
identity=$(security find-identity -v -p codesigning 2>/dev/null \
    | awk -F'"' '/Developer ID Application/ { print $2; exit }')
if [ "$installed_same" -eq 1 ]; then
    printf 'binary unchanged — not reinstalling, so the Accessibility grant is untouched\n'
else
    ./scripts/install.sh >/dev/null
    if [ -n "$identity" ]; then
        codesign --force --options runtime --timestamp --sign "$identity" "$binary"
        printf 'signed with: %s\n' "$identity"
    else
        # The identifier is cosmetic here and does not keep the Accessibility grant: an
        # ad-hoc signature's designated requirement is the binary's own cdhash, which
        # changes on every build whatever the identifier says. Only a certificate moves
        # that requirement to a stable identity, and the owner declined one on purpose —
        # see handovers/2026-08-29-owner-decision-self-signed-certificate.md.
        codesign --force --sign - --identifier dk.hegnsfabrikken.mac-control-mcp "$binary"
        printf 'signed ad-hoc — the grant will drop; re-granting is the intended cost\n'
    fi
fi
printf 'installed: %s (%s)\n' "$binary" "$("$binary" version)"

printf '\n=== publish ===\n'
# Staging everything is how another lane's work gets swept into your commit and pushed
# in the same step, which PROTOCOL.md §2 exists to prevent. The set is printed before
# it is staged, so a sweep is at least never silent; pass explicit paths after the
# message to stage only those.
if [ -n "$(git status --porcelain)" ]; then
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
    git commit -m "$message"
else
    printf 'nothing to commit\n'
fi
git pull --rebase --quiet origin main
git push --quiet
printf 'pushed: %s\n' "$(git rev-parse --short HEAD)"

printf '\n=== next ===\n'
if [ "$installed_same" -eq 1 ]; then
    printf 'Nothing to restart or re-grant: the running server is already this binary.\n'
elif [ -n "$identity" ]; then
    printf 'Restart Claude (Cmd+Q, reopen). Developer ID signed, so re-grant Accessibility\n'
    printf 'once after the first such build; it should hold across later ones.\n'
else
    printf 'Restart Claude (Cmd+Q, reopen), then remove and re-add\n'
    printf '  %s\n' "$binary"
    printf 'in System Settings > Privacy & Security > Accessibility. Ad-hoc signing does\n'
    printf 'not reliably keep the grant across a reinstall.\n'
fi
