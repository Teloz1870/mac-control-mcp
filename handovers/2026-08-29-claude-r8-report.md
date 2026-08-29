REPORT (from claude, round 8)

Assessment: agree with everything outstanding, and reporting an upgrade that exposed two defects in the safety machinery itself plus one the machinery could not have caught.

Commits:    <this round> Read the app version from disk so the gate can actually close
            <this round> Support 0.30.x after verifying it, and diff the landmarks adapters depend on
            <this round> Take the bot name from its label, not from a description carrying unread state

Gates:
- `swift build` → exit 0
- `./scripts/test.sh` → exit 0

Verified:   Grok Bot 0.30.0 admitted to the supported set after a capability diff against
            0.29.0 and a direct check of every landmark the adapter anchors on: "Bot list",
            "Conversation transcript", "Prompt", and the per-row button carrying each bot's
            name. All four unchanged in role, subrole, description and path.

Foreign:    none

What the upgrade found.

1. The version gate could not close. `Bundle(url:)` caches an app's Info.plist for the life of the process, so after Grok Bot updated in place every tool kept answering 0.29.0 and compatible: true against an app that was 0.30.0 on disk. The one mechanism meant to stop the adapter running against an unverified version was reading a number that could no longer change. It had been in that state for the whole afternoon and nothing indicated it. Versions are now read from Contents/Info.plist per call.

   I found this by noticing 0.30.0 in a screenshot of the app's own Updates panel, and I want to record how close it came to going the other way: I concluded the gate was broken before verifying it. `defaults read` on the bundle is what settled it. Had the panel been showing an available rather than an installed version, I would have "fixed" a defect that did not exist and told the owner something was broken.

2. The diff did not compare what adapters depend on. It reported roles, attributes, actions, menus and RPC names, and not the Accessibility descriptions that selectors anchor on. It could have reported no changes while "Bot list" had been renamed and the adapter was entirely broken. It now diffs descriptions, with a test using that exact scenario.

3. And then a defect neither the gate nor the diff could catch. On 0.30 a sidebar row's button description carries transient state: an unread row reads "HF Test Author, Unread activity". Matching on it failed for exactly the bots that had done something. Both snapshots were taken with the same rows read, so the diff saw nothing.

   That is a real limit of the method and is now written into docs/ADAPTERS.md rather than left to be rediscovered: a snapshot diff compares two moments, so it cannot see an attribute that varies with content rather than with version. A selector that passes a diff and fails in use is worse than one that fails both, because the diff keeps saying it is fine.

Risks:      The supported set is now {29, 30} and 0.31 is refused, with a test asserting it.
            The next upgrade needs the same work: scan, diff, check each landmark by hand,
            then widen. The landmark check is still manual — the diff tells you what moved,
            not whether the adapter's own selectors resolve. Wiring the adapter's declared
            selectors into a live self-check would close that, and has not been done.

READY FOR grok REVIEW
