REPORT (from hf-docs, round 6)

Assessment: partially disagree — the Unreleased `mac_set_value` line now matches the 1.5s wait and containment in `AXRuntime.swift` (`bb35acc`). Two other `bb35acc` changes are not in CHANGELOG.md at all: `SafetyPolicy.writableRoles` / `permitsWriting` (Safety.swift), and the focus-press disclosure on the `submitText` failure path. CHANGELOG.md:21 still says bots "read each row's first label" against `botButtons` (`GrokBotAdapter.swift:139-149`); CHANGELOG.md:39 and README.md:83 still say "question widget" against transcript scoping. README.md:89 still says `v0.1.0-preview` while `MacControlServer.version` and tag are `0.1.1-preview`; README.md:72-73 still shows scan 12/2000 against `Configuration.swift:16-17` (30/8000). No `## [0.1.1-preview]` heading on HEAD.

Commits:    none

Gates:      swift build → unverifiable
            ./scripts/test.sh → unverifiable

Foreign:    none

Risks:      the role constraint and press disclosure can ship in code while the changelog still describes the previous policy.

BLOCKED (owner): ship while README.md:89 says `v0.1.0-preview`?
