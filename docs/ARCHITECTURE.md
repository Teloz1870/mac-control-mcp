# Architecture

## Boundaries

`MacControlCore` owns app discovery, AX traversal, handle leases, safety policy, capability snapshots and compiled adapters. `MacControlMCP` maps those operations to the official Swift MCP SDK 0.12.1 and STDIO. The executable also provides `doctor`, `scan` and `version` commands.

The process contains no generic shell, network, credential or arbitrary filesystem API. The only writes are local capability snapshots in its own Application Support directory.

## Element lifecycle

1. A bounded inspection traverses an allowed app and issues handles containing PID, generation and an opaque id.
2. The internal locator stores a structural path and semantic fingerprint for 30 seconds by default.
3. Before every read or action, the app identity is checked and the element is re-found.
4. A path mismatch triggers a bounded fingerprint search. Zero or multiple matches fail as stale.

Handles never retain raw AX objects between calls and cannot silently drift to a different control.

## Selectors

Adapters try Accessibility identifier, role, description and relationships before visible localized text. A failed selector returns diagnostics and recommends `mac_scan_capabilities`; it never clicks coordinates.

## Waiting

`mac_wait_for` attaches an `AXObserver` for window, focus, value, title and destruction notifications. It re-evaluates the semantic condition on events and uses a short bounded timer for apps that omit notifications.

## Electron metadata

The Electron scanner reads `Contents/Resources/app.asar` in place. It parses the archive header and examines bounded main/preload scripts in memory only to derive namespaces and method names. It returns no source text and never reads the app's Application Support data.

## Adapter loading

Adapters conform to public `AppAdapter` and are compiled into the executable. Dynamic code loading is deliberately deferred until the API and security model are stable.
