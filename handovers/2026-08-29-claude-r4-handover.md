HANDOVER (from claude, round 4)

Repo: Teloz1870/mac-control-mcp. Four changes, all found by driving the adapter through a real Grok Bot session rather than by reading the code.

Lanes for this round. Take only yours; do not stage a file another lane owns.

- HF Security owns claim 4. It is the only one that touches a guard, and I should not grade my own homework on it.
- HF Code Peer owns claims 1-3.
- HF Test Author: every claim below that you can express as a pure test over ElementTree or SemanticMatcher, write it. Claim 1 and claim 3 are both expressible without a Mac.
- HF Protocol Keeper: this file, and whether the reports that follow it hold format.

Claims. Reproduce before accepting; refute with file:line when they do not hold.

1. listBots/openBot now read and press the same node. Grok Bot labels each sidebar row with an AXButton whose AXDescription is the bot's name and which exposes AXPress. Previously I read the name from a static text and pressed "the first pressable descendant" of the row.

1b. And then openBot still did not work, which is the more interesting finding: Grok Bot 0.29 advertises AXPress on that row and does nothing with it. The press returns success. The conversation does not change. So openBot now confirms the switch against the AXLandmarkMain title before returning, and throws with that fact when the app ignores its own action. I did not add a coordinate fallback and do not want one — if an app will not honour the action it publishes, that is a fact the caller should receive, not something to paper over. Check whether you agree with that call; it is a usability regression in exchange for honesty and I may be weighing it wrong.

2. answerQuestion is scoped to the transcript landmark and matches the answer's AXTitle. The answers are ordinary buttons carrying their text as a title; there is no widget with an identifier, so my guessed "question-widget" selector could never resolve and the tool failed closed on every call. It failed safely, but it never worked.

3. locate() requires exactly one match. It took the first. Also removed the "Bots" candidate from bot-list: "Bot list" is tried first and always matches, so the fallback could never fire — HF Code Peer called this an overclaim in r3 and was right.

4. submitText presses the element to obtain focus when setting AXFocused does not take. My argument, which is what I want tested: this does not loosen the guard. The requirement is unchanged — the element must hold AXFocused before any key event is sent. What changed is that we make one legitimate attempt to satisfy it first. A press is delivered to a single element that was revalidated by fingerprint immediately beforehand and cannot drift to another control; the Return it guards is a synthetic event with no addressee at all. The two are not the same class of action.

   Refute this if you can. The case I cannot rule out myself: an element that takes focus on press but also performs something else on press. If that exists in Grok Bot 0.29 I want to know before this ships.

5. mac_set_value reads the value back and fails when the element did not keep it. Found by using it: I set five bot descriptions through it, every call returned {"set": true}, and not one was saved. The field accepted the write into its node, never fired the event its framework listens for, and restored the old text on the next render — so the attribute read back correctly for a moment and the app never knew. I only caught it because a later screenshot showed the original English text.

   This is the third instance today of the same failure, and the pattern is worth naming: an operation that reports success without acting is worse than one that fails, because the caller has no way to find out. list_bots returned an empty array that read as "no bots". open_bot returned {"opened": name} without switching. set_value returned {"set": true} without saving. All three were found by using the tool, none by reading the code, and each looked correct on the page.

Protected files: (none). Working tree clean at the commit carrying this file.

Gates:
- `swift build` → exit 0
- `./scripts/test.sh` → exit 0

Still open from r2, not addressed here and not disputed: closeMenus is best-effort and can leave a menu on screen; the lazy submenu open still retries only on a fully empty child list.

READY FOR grok REVIEW
