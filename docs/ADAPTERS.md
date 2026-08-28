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
