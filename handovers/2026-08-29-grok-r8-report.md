REPORT (from grok, round 8)

Assessment: agree with claude r8 on the three code claims, and reporting that task 2 (an Accessibility path for grokbot_open_bot) has none in committed evidence. I will not ship a guessed one.

            Disk version: AXRuntime.swift:79-84 reads Contents/Info.plist; appInfo and CapabilityScanner.scan use bundleVersion, so an in-place 0.30 update is no longer cached as 0.29 for the life of the process. verifiedMinors is {"29","30"} (GrokBotAdapter.swift:68-72). botEntries takes the name from the row's first descendant AXStaticText and still presses the button, falling back to description only if the label is missing (GrokBotAdapter.swift:153-164 / 34b7430). The live landmark check that admitted 0.30 is unverifiable from git: no snapshot JSON is in the repo. r8 Commits used <this round> three times; the hashes are 83b2ed9, 92a2b79, 34b7430 (transport 958f5b5).

            After that READY: eab11daf closes the grok r7 hole — kept("hello","he") is now false because probe is min(comparedPrefix, written.count) and readback.count must be >= probe (Models.swift). 0c9f4ff (self-test as the always-run gate) is also work after READY; it was not an r8 claim.

            Task 2. Kenni's AXPress no-op is already what openBot does: it presses the sidebar AXButton, waits on AXLandmarkMain title, and throws with no coordinate fallback (GrokBotAdapter.swift:176-198). The three untried paths, from code not from a live tree:

            1. AXSetFocused. There is no public focus setter. The only AXFocused write is inside submitText (AXRuntime.swift:197). mac_set_value writes kAXValueAttribute and only to writable text roles (AXRuntime.swift:162-169, Safety.swift writableRoles). ElementSnapshot does not record focused, selected, or settability (Models.swift). This path cannot be attempted through current MCP. Focus is not activate; I will not add a silent focus-then-Return to openBot (Return is the same synthetic key submitText already refuses unless that element holds focus, and a sidebar row is not a text field).

            2. Row children / AXLink. botEntries uses descendants only for the AXStaticText name; it never presses a child (GrokBotAdapter.swift:159-163). An app-wide roles diff that added AXLink is not a row child that opens a conversation. mac_inspect_app returns role, actions, childCount and path, so this path can be probed with existing tools: inspect, take descendants of the matching AXButton, mac_perform_action on any child that exposes AXPress or AXConfirm, confirm against AXLandmarkMain. No such dump is in git.

            3. Sidebar search. No selector. AXSearchField is writable. Writing a name still needs an activation; if the hits are the same AXButtons, AXPress still no-ops. AXConfirm on the field is untested. Probe: mac_find_elements role AXSearchField (and AXTextField) on com.anysphere.sand.

            I cannot live-drive Grok Bot. Inventing a working path would be a claim without evidence. The honest error at GrokBotAdapter.swift:198 stays.

Commits:    none

Gates:      swift build → unverifiable
            ./scripts/test.sh → unverifiable
            live AX on Grok Bot 0.29/0.30 → unverifiable

Foreign:    none

Risks:      pressing a guessed AXLink child would look like a fix and fail the same silent no-op; hf-docs r8 still has README 0.29.x against verifiedMinors {29,30} (not this lane).

BLOCKED (owner): probe one sidebar row's children (role, actions, description, path) and any search field under Bot list with mac_inspect_app / mac_perform_action / mac_find_elements; confirm against AXLandmarkMain title; commit a redacted excerpt to handovers/ (no conversation text). If none of those actions switch the conversation, the honest error is the answer. AXSetFocused needs Accessibility Inspector or a new MCP surface — do not add it to openBot without that evidence.
