REPORT (from hf-docs, round 4)

Assessment: disagree — the version hole is still open in the documents. `MacControlServer.version` is `0.1.1-preview` (MCPServer.swift) and the `version` CLI prints it; tag and release are `v0.1.1-preview`; README.md:89 still says `v0.1.0-preview`. CHANGELOG.md on HEAD `d03c020` has no `## [0.1.1-preview]` heading (that section existed at the tag and was folded back into [Unreleased], while the footer still links `[0.1.1-preview]` at CHANGELOG.md:60). README.md:72-73 still shows `maximumScanDepth` 12 / `maximumScanNodes` 2000 against `MacControlConfiguration.default` 30 / 8000 (Configuration.swift:16-17), which is the empty-list failure the changelog describes. Of the Unreleased Fixed lines: same-node bots (`GrokBotAdapter.swift:139-149`), openBot confirm, unique `locate` (`:119-128`), removed `Bots` fallback (`:28-29`), transcript-scoped answers (`:230`) and read (`:186-189`), press-to-focus, `kAXFocused` readback, and ElementTree empty-path all match the code. Two lines do not: CHANGELOG.md:21 "read each row's first label" is leftover — `botButtons` reads `AXButton.description`; CHANGELOG.md:39 "presses only inside the resolved question widget" contradicts both the newer transcript bullet and the code (no `question-widget` selector; README.md:83 and the tool description at GrokBotAdapter.swift:44 repeat that stale widget claim). `mac_set_value` readback is immediate `ValueWritePolicy.kept` (`contains`, Models.swift:109) — it does not wait for the restore-on-render the changelog narrates, and that policy is absent from CHANGELOG. `mac_inspect_app` still defaults to depth 6 / 500 nodes (MCPServer.swift). Path `handovers/2026-08-29-claude-r5-report.md` is not at HEAD `d03c020`.

Commits:    none

Gates:      swift build → unverifiable
            ./scripts/test.sh → unverifiable

Foreign:    none

Risks:      copying the README config example restores the scan depth that made `grokbot_list_bots` look like "no bots".

BLOCKED (owner): ship while README.md:89 says `v0.1.0-preview` and CHANGELOG.md has no `## [0.1.1-preview]` section?
