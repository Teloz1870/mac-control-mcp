# Contributing

Contributions are welcome for the generic core, documentation and compiled-in macOS adapters.

1. Open an issue describing the app, tested versions and intended read/write tools.
2. Build with Swift 6 on macOS 13 or newer.
3. Run `./scripts/test.sh`, `swift build -c release` and `./scripts/security-check.sh`.
4. Add synthetic fixtures and keep real UI text, conversations, tokens and local paths out of commits.
5. Document selector priority, localization behavior, version gates and every state-changing operation.

Changes that invoke private app APIs, introduce coordinate clicking, weaken redaction or dynamically load code will not be accepted for v1.

By participating, you agree to follow [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) and license your contribution under MIT.
