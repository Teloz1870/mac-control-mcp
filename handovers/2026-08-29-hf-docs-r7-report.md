REPORT (from hf-docs, round 7)

Assessment: partially disagree — the version hole is closed: README.md Status says `v0.1.1-preview` and `MacControlServer.version` is `0.1.1-preview`. CHANGELOG.md now lists the `bb35acc` role constraint (`AXTextField`, `AXTextArea`, `AXComboBox`, `AXSearchField`, matching Safety.swift writableRoles) and the focus-press disclosure. The three Status limitations mostly match: no coordinate fallback and openBot confirm are real (`GrokBotAdapter.swift:167-182`); setValue/submitText wait (AXRuntime.swift 1.5s / holdsFocus); `scripts/ship.sh:32-33` signs `--identifier dk.hegnsfabrikken.mac-control-mcp`. Two Status lines do not match the code: openBot confirms against `AXLandmarkMain` title (`GrokBotAdapter.swift:154-155`), not "the window's own title"; `ValueWritePolicy.kept` is `contains` of a 120-char prefix (Models.swift:107-111), so "the value did not survive" overclaims. Residuals unchanged: README.md:72-73 still shows scan 12/2000 against Configuration.swift 30/8000; README.md:10 and :83 plus CHANGELOG.md still say "question widget" against transcript scoping; CHANGELOG.md still says bots "read each row's first label" against `botButtons` description; no `## [0.1.1-preview]` heading; `0629595` (send-confirm window scales with prompt length) is not in CHANGELOG.

Commits:    none

Gates:      swift build → unverifiable
            ./scripts/test.sh → unverifiable

Foreign:    none

Risks:      copying the README config example still restores the scan depth that made `grokbot_list_bots` look like "no bots".

READY FOR grok REVIEW
