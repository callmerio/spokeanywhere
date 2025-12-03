# Conventions & Style Guide

## Code Style
The project enforces code style using **SwiftLint**.
*   **Configuration File**: `.swiftlint.yml` (in project root).
*   **Line Length**:
    *   Warning: 120 characters.
    *   Error: 200 characters.
*   **Identifier Names**: 2 to 50 characters.
*   **Disabled Rules**: `trailing_whitespace`, `todo`, `orphaned_doc_comment`.
*   **Opt-in Rules**: `empty_count`, `closure_spacing`, `explicit_init`, `first_where`, `sorted_imports`, etc.

## Directory Structure
*   Source code is located in `spoke/`.
*   The `Package.swift` is located in `spoke/`.
*   **Important**: When running `swift` commands, you must be in the `spoke/` directory.

## Naming Conventions
*   Follow standard Swift API Design Guidelines.
*   Use `UpperCamelCase` for types and protocols.
*   Use `lowerCamelCase` for properties, methods, and variables.
*   Prefer clear, descriptive names over abbreviations.

## Documentation
*   Use Swift Markdown for documentation comments (`///`).
*   Keep `README.md` and `docs/` updated with architectural decisions.
