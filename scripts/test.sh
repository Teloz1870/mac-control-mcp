#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

# The self-test is the gate that always runs. It is a plain executable, so it needs no
# Xcode and no test runner, and every rule worth guarding is asserted there.
swift run mac-control-self-test

# The swift-testing suite needs xctest, which ships with Xcode and not with the Command
# Line Tools. Where it is missing, `swift test` builds the bundle, runs nothing, and exits
# 0 — a gate that measured nothing while reporting success, which is worse than no gate.
# So it is only claimed as a gate where it can actually execute.
if ! xcrun --find xctest >/dev/null 2>&1; then
    printf '\n%s\n' 'note: xctest is unavailable (no Xcode), so the swift-testing suite'
    printf '%s\n' '      cannot run here. CI runs it; locally the self-test above is the gate.'
    exit 0
fi

output=$(swift test --enable-swift-testing 2>&1) || {
    printf '%s\n' "$output"
    exit 1
}
printf '%s\n' "$output"

if ! printf '%s' "$output" | grep -Eq 'Test run with [0-9]+ test|Executed [0-9]+ test|[0-9]+ tests? passed'; then
    printf '\n%s\n' 'swift test exited 0 without reporting a test run.' >&2
    printf '%s\n' 'That is not a pass, it is a gate that measured nothing.' >&2
    exit 1
fi
