# Suggested Commands

## 🚀 Preferred Run Command (Dev)
**Use this command to restart the app during development:**
```bash
cd /Users/bigdan/Workspace/macos/spokeanywhere/spoke && pkill -f SpokenAnyWhere 2>/dev/null; swift build; swift run SpokenAnyWhere
```

## Build & Run
**Note**: All commands should be run from the `spoke/` directory unless otherwise specified.

*   **Build (Debug)**:
    ```bash
    cd spoke && swift build
    ```
*   **Build (Release)**:
    ```bash
    cd spoke && swift build -c release
    ```
*   **Run (Standard)**:
    ```bash
    cd spoke && swift run
    ```

## Release
*   **Build App Bundle & DMG**:
    ```bash
    ./scripts/build-release.sh
    ```
    *   Output: `spoke/dist/SpokenAnyWhere.app` and `spoke/dist/SpokenAnyWhere.dmg`.

## Code Quality
*   **Lint Code**:
    ```bash
    swiftlint
    ```
    (Requires `swiftlint` to be installed on the system).

## Testing
*   **Run Tests**:
    *   *Current Status*: No test target is defined in `Package.swift`.
    *   Standard command would be: `cd spoke && swift test`.

## File System
*   **Find Files**:
    ```bash
    find . -name "*.swift"
    ```
