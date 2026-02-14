# Test Isolation Rules

## No Shared State Rule

- Stateful tests **must not** depend on global persisted state.
- Do not read/write production storage paths (`Application Support`, default `UserDefaults`) in unit tests.
- Prefer constructor injection with per-test temp paths.

## Applied Modules

- `VocabularyServiceTests`: uses `makeIsolatedService()` with unique temp file path.
- `TagLibraryTests`: uses `makeIsolatedLibrary()` with unique temp file paths for tags/recent tags.
- `AppSettingsTests` and `TranscriptionModelManagerTests`: marked `.serialized` to avoid race conditions on shared singleton state.

## Enforcement Checks

- Add explicit tests that verify isolated instances do not share persisted data.
- Keep cleanup local to the test instance; never mutate shared singletons for stateful test assertions.
