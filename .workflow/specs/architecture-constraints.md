<spec-entry category="arch" keywords="macos,swiftui,appkit,service-container" date="2026-04-27" source="CLAUDE.md">
SpokenAnyWhere is a native macOS 14+ SwiftUI/AppKit hybrid app using ServiceContainer for runtime dependencies. New features should integrate through existing service, dependency, and lifecycle patterns.
</spec-entry>

<spec-entry category="arch" keywords="lifecycle,ownership,cleanup,manager,observer" date="2026-04-27" source="autoresearch-lessons.md">
Lifecycle managers should have explicit owner/register/cleanup inventories. A green build is not enough for release readiness if observers, callbacks, timers, windows, or long-lived services do not have documented ownership and teardown behavior.
</spec-entry>

<spec-entry category="arch" keywords="dependency-channel,shared,notificationcenter,state-sink" date="2026-04-27" source="autoresearch-lessons.md">
New coupling must use an allowed dependency channel. Prefer ServiceContainer/dependency structs and direct callbacks for owned flows; keep NotificationCenter to explicit allowlisted cross-surface events; avoid introducing new `.shared` call sites in UI or hot-path orchestration.
</spec-entry>
