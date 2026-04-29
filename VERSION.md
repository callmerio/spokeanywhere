# SpokenAnyWhere Version Rules

Current version: `0.3.0`

SpokenAnyWhere uses pre-1.0 semantic versioning with milestone-driven minor releases.

## Version Semantics

- **MAJOR**: breaking API or behavior changes.
- **MINOR**: new features or milestone harvests. Wave1 Harvest is `0.3.0`.
- **PATCH**: bug fixes and small improvements that do not redefine the current milestone.

## Tag Format

- Stable releases use `vMAJOR.MINOR.PATCH`, for example `v0.3.0`.
- Beta releases may use `vMAJOR.MINOR.PATCH-beta.N` when a milestone is usable but not stable.

## Release Discipline

- Keep in-progress changes in `CHANGELOG.md` under `Unreleased`.
- Promote `Unreleased` entries into a version section when a milestone is tagged.
- Prefer milestone clarity over commit-count-based version bumps.
