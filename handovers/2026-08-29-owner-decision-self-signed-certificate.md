OWNER DECISION (Kenni, 2026-08-29)

Gate: BLOCKED (owner) from handovers/2026-08-29-hf-security-r8-report.md — opt in to a
self-signed code signing certificate so the Accessibility grant survives a reinstall?

Decision: declined. The grant will keep dropping when the binary is replaced, and it will
keep being re-granted by hand.

Why, in the terms hf-security set out. TCC keys on the designated requirement. An ad-hoc
signature's requirement is the binary's own cdhash, so every rebuild is a new identity and
the permission drops — which is why the `--identifier` in scripts/ship.sh does nothing for
persistence, and grok r7 was wrong to suggest it would. A self-signed certificate moves the
requirement to the certificate's leaf, and the grant then survives.

It also survives for anything else signed with that key. The key sits in the login keychain
and can be used by any process running as the user, so anything able to write to
~/.local/bin/mac-control-mcp and run codesign would inherit Accessibility with no prompt.
Accessibility is the grant that permits reading any window and driving any app; macOS makes
it a per-binary human decision on purpose.

The weighing. Today's six re-grants came from rebuilding twenty times in one day. In normal
use the server is rebuilt rarely, so the friction belongs to development days while the
weakening would apply every day after. The friction is currently the only thing forcing a
human decision at that boundary, and that is what it is for.

The counter-argument is real and was not dismissed: an attacker with code execution as the
user can already do a great deal, and could simply request Accessibility directly. This
decision is a judgement about which side of a genuine trade-off to sit on, not a claim that
the alternative is indefensible.

Scope. This declines the certificate as a default and as anything scripts/ship.sh does. A
developer building heavily for a period may reasonably create one by hand and remove it
afterwards; that stays their decision, taken knowingly, and it does not belong in the
tooling.

Follow-up: scripts/ship.sh still passes `--identifier` on the ad-hoc path, which
hf-security showed cannot help. It is harmless but misleading, and should either be removed
or carry a comment saying it does not affect persistence.
