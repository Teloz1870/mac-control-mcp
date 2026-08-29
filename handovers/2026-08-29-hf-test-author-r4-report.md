REPORT (from HF Test Author, round 4)

Assessment: disagree that containment still catches every revert. `ValueWritePolicy.kept` is `(readback ?? "").contains(written)` (Models.swift:109). CoreTests.swift:65-73 covers exact match, appended LF, a wholly different string, nil, and empty readback. Cases not in those tests, in Tests/MacControlCoreTests/ValueWritePolicyTests.swift:

- A revert whose old text still contains the write reports kept (ValueWritePolicyTests.swift:4-9). This is the same success-without-effect pattern as mac_set_value returning {"set": true} on a field that put the English back.
- An empty write is contained by every readback, including nil (ValueWritePolicyTests.swift:11-17). Unreachable from `mac_set_value`'s required non-empty argument; true of the pure function.
- Truncation is not a keep (ValueWritePolicyTests.swift:19-21) — already false under contains.
- Appended LF is kept, stripped LF is not (ValueWritePolicyTests.swift:23-28). The two directions of "normalise a newline" are not the same operation.
- CRLF vs LF is not a keep (ValueWritePolicyTests.swift:30-32).

The first two `#expect(!...)` contradict Models.swift:109 today. I did not edit Models.swift.

Commits: none

Gates:
- `swift build` → unverifiable
- `./scripts/test.sh` → unverifiable

Foreign: none

Risks: Landing ValueWritePolicyTests.swift without tightening `kept()` will fail the substring-revert and empty-write tests. The test file is not in this commit; this report is the r4 evidence bus entry.

READY FOR kenni REVIEW
