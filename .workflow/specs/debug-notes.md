<spec-entry category="debug" keywords="tcc,sanitizer,macos,privacy" date="2026-04-27" source="PROJECT.md">
Thread and address sanitizer verification may be CI-only because local macOS SIP/Hardened Runtime policy can block sanitizer loading. Treat this as an environment constraint, not automatically a code failure.
</spec-entry>

<spec-entry category="debug" keywords="screen-capture,control-center,sensor-indicators,screenpipe,live-caption" date="2026-04-27" source=".worktrees/screen-capture-indicator-fix/spoke/.draft.md">
When verifying whether SpokenAnyWhere is using screen capture at cold start, do not rely only on generic Control Center wording if a resident recorder such as screenpipe is running. Use ControlCenter sensor-indicators attribution: baseline should not show com.spokeanywhere before Live Caption is actively started; after Live Caption closes, attribution should fall back to the non-SpokenAnyWhere recorder only.
</spec-entry>
