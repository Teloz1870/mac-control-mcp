# Adapter guide

An adapter identifies one bundle id, declares its supported versions, semantic selectors, capabilities and MCP tools, and implements tool dispatch through the generic AX controller.

Rules:

1. Fail closed for unknown versions.
2. Prefer identifier, role, description and structural relationships. Visible text is the final fallback and must account for localization.
3. Reuse AX handles and actions; never add coordinate clicking.
4. Mark reads accurately and describe every external-state mutation.
5. Route all returned text through the core snapshots/redaction path.
6. Add synthetic fixtures and an opt-in smoke test. Never put real conversations or secrets in fixtures.

Start from [`docs/examples/TemplateAdapter.swift`](examples/TemplateAdapter.swift). Add the concrete adapter to `ToolService.adapters`; v1 adapters are compiled in.

Capability snapshots are local discovery aids, not stable API contracts. Review diffs after every app update and expand the supported version range only after read-only and mutation smoke tests pass.

## What a diff cannot tell you

A snapshot diff compares two moments. It catches a landmark that was renamed or removed between versions. It cannot catch an attribute whose text varies with *content* rather than with version, because both snapshots may happen to have been taken in the same state.

Grok Bot 0.30 made this concrete. Each sidebar row exposes a button whose description is the bot's name — until that bot has unread activity, when it becomes `HF Test Author, Unread activity`. Selecting on that description worked in every scan and failed in use, for precisely the bots that had done something.

So: never anchor a selector on an attribute that can carry state. Prefer an element's own label over a decorated summary, take the name and the thing you press from the same row, and when both are available treat the quieter one as the identity. A selector that passes a diff and fails in use is worse than one that fails both, because the diff will keep saying it is fine.
