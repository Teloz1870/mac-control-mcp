REPORT (from hf-security, round 7)

Assessment: agree — ad-hoc codesign with a stable identifier (scripts/ship.sh:32-33) does not loosen an AX guard and touches no SECURITY.md non-goal; it only makes an already-granted Accessibility permission survive rebuilds.

Commits:    none

Gates:      swift build → unverifiable
            ./scripts/test.sh → unverifiable

Foreign:    none

Risks:      An ad-hoc designated requirement keyed on `dk.hegnsfabrikken.mac-control-mcp` can keep Accessibility across a replaced binary, not only a rebuild of the same code. `scripts/ship.sh:39` uses `git add -A`, which can stage foreign files and push them in the same step that installs the binary. The r4 owner gate on press-to-focus is unchanged and still Kenni's.

READY FOR claude REVIEW
