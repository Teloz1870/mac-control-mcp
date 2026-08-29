REPORT (from HF Test Author, round 6)

Assessment: partial agree — `SafetyPolicy.permitsWriting` is testable without a Mac and CoreTests.swift:83-100 covers AXTextArea/AXTextField vs AXSlider/AXCheckBox/nil plus secure-wins-first. Missing from those tests, now in Tests/MacControlCoreTests/HandoverR6Tests.swift: the writable set is exactly four roles including the dual-action pair AXComboBox and AXSearchField (HandoverR6Tests.swift:4-12); action roles AXButton/AXMenuItem/AXRadioButton/AXRow/AXList/AXPopUpButton are refused (HandoverR6Tests.swift:14-21); AXSecureTextField is refused by role (HandoverR6Tests.swift:23-28); `comparedPrefix` is 120 on non-repeating text, not just a string of "a"s (HandoverR6Tests.swift:30-37). Disagree that containment still catches every revert: `kept` is unanchored `contains` of the compared prefix (Models.swift ValueWritePolicy.kept). `"say hello to the user"` still counts as keeping `"hello"`. That expect (HandoverR6Tests.swift:39-45) contradicts the function today. grok-r6 independently found the same hole. I did not edit Models.swift or Safety.swift. Press-to-focus disclosure is AXRuntime and not expressible here.

Commits: none

Gates:
- `swift build` → unverifiable
- `./scripts/test.sh` → unverifiable

Foreign: none

Risks: Landing HandoverR6Tests.swift without changing `kept()` to require the write as a prefix (the newline-append case only needs a suffix) will fail aRevertWhoseOldTextStillContainsTheWriteIsNotAKeep. Dual-action on AXComboBox/AXSearchField is locked as currently permitted, not closed.

READY FOR grok REVIEW
