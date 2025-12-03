# Tech Stack

## Core
*   **Language**: Swift 5.9
*   **Platform**: macOS 14.0+ (Sonoma and later)
*   **Build System**: Swift Package Manager (SPM)
*   **Frameworks**:
    *   **SwiftUI**: For the user interface.
    *   **AVFoundation**: Likely used for audio capture and processing.
    *   **AppKit**: For macOS-specific window management (implied by "LSUIElement" in Info.plist).

## Development Environment
*   **IDE**: Xcode / VSCode (with SourceKit-LSP).
*   **Linter**: SwiftLint.

## Project Structure (`spoke/`)
*   `App`: Main application entry point and lifecycle management.
*   `Core`: Business logic, models, and data structures.
*   `Services`: Backend services, API clients, and audio handling.
*   `UI`: SwiftUI views and view models.
*   `Resources`: Assets and local models.

## Dependencies
*   Currently, the `Package.swift` lists **no external dependencies**, relying on standard libraries.
