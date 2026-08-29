# Changelog

All notable changes follow Keep a Changelog. Versions use Semantic Versioning.

## [Unreleased]

## [0.1.1-preview] - 2026-08-29

### Added

- `grokbot_notify_handover` rings a peer agent's doorbell for the [Agent Handover Protocol](https://github.com/Teloz1870/agent-handover-protocol). It accepts a repo-relative `.md` pointer and nothing else, so the bridge cannot become a second, unversioned transport for handover content, claims or approval.

### Fixed

- The synthetic Return fallback in `submitText` is now delivered to the target process and refused unless that app is frontmost, so it can no longer reach another app.
- `mac_press_menu_item` walks the menu bar level by level and requires an exact single match per component, so `File > Close` can no longer resolve to `Window > Close`.
- `grokbot_answer_question` presses only inside the resolved question widget instead of any app-wide button with the same title.
- `grokbot_run_routine` and `grokbot_set_routine_enabled` locate the control inside the named routine's own row, so more than one routine on screen is no longer ambiguous.

### Changed

- `ElementSnapshot` carries its structural `path`, and `ElementTree` offers containment helpers so adapters can scope a search to one widget. Capability snapshots are now schema 2; snapshots written by earlier builds still decode with an empty path.
- `mac_set_value` and every mutating adapter tool report `destructiveHint` to the host.
- Element snapshots resolve their handle directly rather than scanning the handle table, removing quadratic cost from full scans.

## [0.1.0-preview] - 2026-08-28

### Added

- Swift 6/macOS 13 Accessibility core with expiring, revalidated element handles.
- Ten generic MCP tools over STDIO using the official MCP Swift SDK 0.12.1.
- Grok Bot 0.29.x adapter with nine semantic tools and fail-closed compatibility checks.
- Redacted AX and read-only Electron capability snapshots plus snapshot diffs.
- `doctor`, `scan` and `version` CLI commands.
- Unit fixtures, CI, universal preview release workflow and source-first installer.

[Unreleased]: https://github.com/Teloz1870/mac-control-mcp/compare/v0.1.1-preview...HEAD
[0.1.1-preview]: https://github.com/Teloz1870/mac-control-mcp/compare/v0.1.0-preview...v0.1.1-preview
[0.1.0-preview]: https://github.com/Teloz1870/mac-control-mcp/releases/tag/v0.1.0-preview
