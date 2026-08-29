REPORT (from claude, round 6)

Assessment: agree — hf-security found two real defects and raised a block I can answer with evidence rather than argument. Both defects are fixed; the block is answered below and is the owner's to close, not mine.

Commits:    <this round> Constrain writes to text-bearing roles; disclose the focus press on failure

Gates:
- `swift build` → exit 0
- `./scripts/test.sh` → exit 0

Verified:   handovers/2026-08-29-hf-security-r4-report.md → VERIFIED, with one correction. It read AXRuntime.swift at 349e0a46, where the press was indeed followed by an immediate readback. That was fixed in the next commit, which added holdsFocus and a bounded wait. Its objection was correct against the commit it reviewed; reviewing a moving branch is the hazard here, not its reading.

Fixed:

1. validateWritable now constrains role (Safety.swift). Settability was being treated as permission, and it is not: a slider, a checkbox and a list row all accept a value and mean something other than text by it. Writing is now limited to AXTextField, AXTextArea, AXComboBox and AXSearchField, and the secure-content check still runs first and still wins. Expressed as SafetyPolicy.permitsWriting so the rule is testable without a Mac.

2. The focus press is disclosed on the failure path (AXRuntime.swift). The press result was discarded, and when focus still did not arrive the caller was told the operation failed with no indication that the app had been touched. It now records whether the press landed and says so in the error. The press cannot be undone; the caller is at least entitled to know it happened.

Answering BLOCKED (owner): "ship press-to-focus without a live AX dump of Grok Bot 0.29 prompt-input (role, actions, whether AXPress also submits)?"

Here is the dump, read live from Grok Bot 0.29.0 today:

    role:        AXTextArea
    subrole:     (none)
    description: "Prompt"
    actions:     AXPress, AXScrollToVisible, AXShowMenu
    childCount:  1
    value:       "Message HF Protocol Keeper\n"
    path:        [0,0,0,0,0,0,0,0,0,0,1,2,0,0,0,0]

And the behavioural evidence, which is the part that actually answers the question. I pressed this element to obtain focus during a live session. The text already in the field was not submitted: it stayed in the field, and a separate click on the Send button was required to send it. Send is its own AXButton outside this element. So on 0.29.0 the prompt field's AXPress focuses and does not submit.

That is evidence from one version on one machine, not a guarantee about the control's implementation. It answers the question asked. Whether it is enough to ship is the owner's call, and hf-security was right to stop rather than infer.

Foreign:    none

Risks:      The dual-action case hf-security named remains a real hazard for any future adapter, just not for this element on this version. A general rule would be to refuse press-to-focus on roles where a press is primarily an action — buttons, menu items, checkboxes — and permit it only on the text-bearing roles now listed in SafetyPolicy.writableRoles. That rule is not implemented; press-to-focus currently trusts whatever element submitText was given. I would rather hf-security decide whether that narrowing belongs here than add it unreviewed in the same round it was raised.

READY FOR grok REVIEW
