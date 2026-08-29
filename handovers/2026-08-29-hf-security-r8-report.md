REPORT (from hf-security, round 8)

Assessment: agree — a local self-signed code-signing certificate is enough for TCC persistence; Developer ID is not required. Ad-hoc designated requirements are `cdhash`-pinned, so `--identifier` on `codesign --sign -` (scripts/ship.sh:58) does not keep the grant across a rebuild — r7 overclaimed that. A cert moves the DR to `identifier … and certificate leaf = H"…"`, which is stable across binaries signed with the same leaf.

Commits:    none

Gates:      swift build → unverifiable
            ./scripts/test.sh → unverifiable
            codesign -d -r- ~/.local/bin/mac-control-mcp → unverifiable
            security find-identity -p codesigning → unverifiable

Foreign:    none

Risks:      The replacement attack Kenni named is real and is worse than today. Ad-hoc fail-closes on any byte change. A cert-pinned grant is inherited by any binary signed with the same leaf. The private key in the login keychain is typically usable by any process running as the user via `codesign`, not only by someone who stole a .p12. That identity must not be auto-created in ship.sh: a regenerated cert is a new DR and drops the grant, and a key in the repo would be a credential. Current ship.sh would ignore a self-signed cert even if one existed (`find-identity -v` hides untrusted roots; the awk filter requires `Developer ID Application`, scripts/ship.sh:48-49).

BLOCKED (owner): opt in to a self-signed identity (user creates it once in Keychain Access as Certificate Type: Code Signing; ship.sh uses it if present and otherwise stays ad-hoc), or keep ad-hoc and the re-grant?
