# ADR-001: Offline-first architecture
Status: Accepted
## Context
Conferences may have no connectivity, and captured speech can be sensitive.
## Decision
Core captions execute on device. No remote fallback, accounts, tracking, stored audio or API keys. Separate optional future AI and explicitly disclose any model installation connectivity.
## Alternatives considered
Cloud recognition; rejected because it violates the primary requirement.
## Consequences
Device, locale and asset readiness must be explicit; supported hardware requires real-device validation. Phase 0 makes no readiness claim.
