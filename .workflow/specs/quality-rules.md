<spec-entry category="quality" keywords="build,test,concurrency,design-tokens" date="2026-04-27" source="CLAUDE.md">
Meaningful code changes should be validated from spoke/ with swift build, swift test --parallel, and Tests/run-concurrency-check.sh where applicable. UI styling must use DesignTokens exclusively.
</spec-entry>

<spec-entry category="quality" keywords="architecture-gate,failure-classes,logs,provider-neutral" date="2026-04-27" source="autoresearch-lessons.md">
Architecture quality gates should be provider-neutral and report failure classes with log paths. Do not treat a vague gate failure as actionable until it identifies the owning layer, rule, and evidence path.
</spec-entry>

<spec-entry category="quality" keywords="interaction-proof,smoke-tests,foreground-ui,proof-map" date="2026-04-27" source="autoresearch-lessons.md">
Foreground interaction changes need an explicit proof map: target surface, entry point, injected dependency path, and smoke or unit coverage. Existing smoke tests can be reused when they prove the changed interaction boundary.
</spec-entry>
