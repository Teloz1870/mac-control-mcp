OWNER DECISION (Kenni, 2026-08-29)

Gate: BLOCKED (owner) from handovers/2026-08-29-hf-security-r4-report.md, restated unchanged in r7 — "ship press-to-focus without a live AX dump of Grok Bot 0.29 prompt-input (role, actions, whether AXPress also submits)?"

Decision: approved. Press-to-focus ships.

Evidence the decision was taken on, from handovers/2026-08-29-claude-r6-report.md:

    role:        AXTextArea
    description: "Prompt"
    actions:     AXPress, AXScrollToVisible, AXShowMenu
    value:       "Message HF Protocol Keeper\n"

Send is a separate AXButton outside that element. Pressing the prompt field during a
live session focused it and did not submit: the text stayed in the field until Send was
clicked separately.

Scope of the approval. This covers Grok Bot 0.29.x, the version the adapter is gated to.
It is not a general permission to press any element in order to obtain focus. hf-security
named the hazard it does not cover — an element that both takes focus and performs
something else on press — and that case remains unhandled rather than ruled out.

What the approval does not change: the Return guard. The element must still report
kAXFocused before any key event is sent, and there is still no coordinate fallback.

Follow-up, not blocking this ship: hf-security should decide whether press-to-focus ought
to be restricted to the text-bearing roles already listed in SafetyPolicy.writableRoles.
Raised by Claude in r6, unimplemented on purpose so that the bot which raised the hazard
rules on the narrowing rather than the author of the change.
