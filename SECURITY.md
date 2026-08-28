# Security policy

## Supported versions

Security fixes are provided for the latest tagged preview and, after 1.0, the latest stable minor release.

## Reporting

Do not open a public issue for a vulnerability. Use GitHub's private vulnerability reporting for `Teloz1870/mac-control-mcp`. Include the affected version, reproduction steps and impact; never include live credentials, wallet material or private conversations.

## Threat model

The server runs with the Accessibility permission granted by its user. That permission is powerful, so the default bundle allowlist contains only Grok Bot. Generic actions operate only on handles minted from an allowed app, handles expire, app/PID identity is rechecked and element fingerprints must match.

The server blocks AX secure text fields and metadata associated with passwords, secrets, tokens, cookies, sessions, credentials, private keys, seed phrases, wallets and payment data. Likely secrets embedded in otherwise ordinary strings are redacted. Logs contain tool name, duration, bundle id and error type only.

The Electron scanner reads only resources inside the resolved `.app` bundle. It does not unpack source, return source text, inspect Application Support, or invoke discovered RPC names. Snapshot reads are constrained to the server's own Application Support directory.

## Explicit non-goals

- No screen-coordinate fallback
- No private Grok Bot coordinator RPC calls
- No shell or arbitrary command execution
- No network operations
- No credential or wallet access
- No dynamic third-party adapter loading in v1

Review any allowlist expansion and adapter mutation tool as a security-sensitive change.
