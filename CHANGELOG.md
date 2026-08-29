# Changelog

All notable changes follow Keep a Changelog. Versions use Semantic Versioning.

## [Unreleased]

### Added

- Grok Bot 0.30.x is supported, admitted the way the range is meant to be widened: a capability diff against 0.29.0, then a direct check that every landmark the adapter anchors on still resolves. Supported minors are now an explicit set rather than a single hardcoded number, so admitting one is a deliberate act.
- `grokbot_list_bots` and `grokbot_open_bot` take each bot's name from the row's own label rather than the row button's description. On 0.30 that description carries transient state — an unread row reads `HF Test Author, Unread activity` — so it identifies the row but is not the name, and matching on it would fail for exactly the bots that have something to say. Found by upgrading, not by the diff: a description that changes with unread state cannot be caught by comparing two snapshots.
- `mac_diff_capabilities` reports added and removed Accessibility descriptions. Roles, actions and menus say whether the app changed shape; the descriptions say whether an adapter's selectors still land, which is the question the diff exists to answer. It did not compare them until now.

### Fixed

- The version gate read a cached version and so did not close. `Bundle(url:)` caches an app's Info.plist for the life of the process, so after Grok Bot updated in place every tool kept answering `0.29.0` and `compatible: true` while the app on disk was `0.30.0`. The one mechanism meant to stop the adapter running against an unverified version was reporting a number that could no longer change. Versions are now read from `Contents/Info.plist` on each call, in `mac_list_apps`, `grokbot_get_status` and the capability snapshot alike.

Found by driving the adapter through a real session, and by peer review of r3:

- `grokbot_list_bots` and `grokbot_open_bot` now use the button Grok Bot already labels with each bot's name, so the name read and the element pressed are the same node. The previous version read a label from one node and pressed a guessed sibling.
- `mac_scan_capabilities` returns a summary and the snapshot's path instead of the hierarchy. A full tree runs past 300,000 characters and could not be returned over STDIO at all, so the tool failed at the one thing it exists for. The snapshot on disk is unchanged and is what `mac_diff_capabilities` reads.
- Values may only be written to text-bearing roles (`AXTextField`, `AXTextArea`, `AXComboBox`, `AXSearchField`). Settability was being treated as permission: a slider, a checkbox and a list row all accept a value and mean something other than text by it. The secure-content check still runs first and still wins.
- `submitText` says so in the error when it pressed the element to obtain focus and focus still did not arrive. The press cannot be undone, and a caller being told the operation failed is entitled to know the app was touched on the way there.
- `mac_set_value` reads the value back — after giving the app up to 1.5s to render, and by containment rather than equality — and fails when the element did not keep it. Checking too early, or demanding an exact match, rejects writes that plainly worked: the same unreliability this check exists to prevent, pointing the other way. Web-backed fields accept the write into their node without firing the event their framework listens for, then restore the old text on the next render: the attribute read correctly for a moment, the app never knew, and the tool reported `{"set": true}`.
- `grokbot_open_bot` confirms the conversation actually changed before returning. Grok Bot 0.29 advertises `AXPress` on a sidebar row and then ignores it, so a successful press proved nothing and the tool reported switches that never happened. It now fails with that fact instead, and still offers no coordinate fallback.
- `grokbot_answer_question` is scoped to the conversation transcript and matches the answer's `AXTitle`. The answers are plain buttons carrying their text as a title, not a widget with an identifier — the guessed `question-widget` selector could never resolve, so the tool always failed closed.
- Selector resolution requires a single match. Taking the first of several silently picks a winner the caller never chose. The `Bots` fallback for the bot list is gone: it could never win over `Bot list`, so it claimed a fallback that did not exist.
- `submitText` presses the element to obtain focus when setting `AXFocused` does not take. The requirement is unchanged — the element must hold focus before a key is sent — but a press is scoped to one revalidated element and cannot land elsewhere, unlike the Return it guards.

Found by running the adapter against Grok Bot 0.29 for the first time:

- The scan depth of 12 stopped above everything that matters. Grok Bot derives its Accessibility tree from the DOM, so its sidebar sits past depth 18 — `grokbot_list_bots` returned an empty list rather than an error, which reads as "no bots" instead of "I did not look far enough". Default depth is now 30 and 8000 nodes, and the adapter uses the configuration instead of six hardcoded limits.
- `grokbot_list_bots` and `grokbot_open_bot` now anchor on the app's own `Bot list` landmark and read each row's first label. They previously matched any `AXButton` carrying a title, which found suggestion chips.
- `grokbot_read_conversation` is scoped to the `Conversation transcript` landmark and returns one entry per `AXDocumentArticle`, sender and timestamp included. It previously swept every static string in the app, so the settings panel appeared as conversation.
- `submitText` trusts the `kAXFocused` readback rather than requiring the setter to also report success; a field that already held focus was refused.

Three defects found by peer review of `d51cef4` ([report](handovers/2026-08-29-grok-r1-report.md)):

- `ElementTree` no longer accepts an element with an empty path as a container. Every path starts with the empty path, so a root element or a pre-schema-2 snapshot silently became the ancestor of the whole app — defeating the widget scoping these helpers exist to enforce.
- `mac_press_menu_item` opens a submenu that reports no children and looks again, because many apps populate a submenu only once it is opened. Menus opened during a failed walk are closed again.
- `submitText` verifies the element actually holds keyboard focus before posting Return. Frontmost settles only which app receives the key, not which field.

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
