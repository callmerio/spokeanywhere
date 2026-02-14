# Contributing to SpokenAnyWhere

Thank you for your interest in contributing to SpokenAnyWhere! This guide will help you get started.

## Table of Contents

- [Development Environment Setup](#development-environment-setup)
- [Project Structure](#project-structure)
- [Code Standards](#code-standards)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Quality Playbook](#quality-playbook)

## Development Environment Setup

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Xcode 15.0+ with Command Line Tools
- Swift 5.9+
- [Swift Bundler](https://github.com/stackotter/swift-bundler) for `.app` packaging

### Initial Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/spokeanywhere.git
   cd spokeanywhere
   ```

2. **Install Swift Bundler** (if not already installed)
   ```bash
   brew install stackotter/tap/swift-bundler
   ```

3. **Build and run**
   ```bash
   cd spoke
   ./dev.sh
   ```

   The `dev.sh` script handles:
   - Building the app
   - Code signing with developer certificates
   - Launching with live logging

### Required Permissions

The app requires TCC (Transparency, Consent, and Control) permissions:

| Permission | Purpose |
|------------|---------|
| Microphone | Voice recording |
| Screen Recording | Live caption, screenshot |
| Accessibility | Text selection detection |

**Important**: Ad-hoc signing breaks TCC permissions. Always use `dev.sh` which handles proper code signing.

### Viewing Logs

```bash
# Live logs during development
tail -f spoke/.tmp_frames/dev-*.log

# Filter for errors
grep -E 'error|Error|❌' spoke/.tmp_frames/dev-*.log
```

## Project Structure

```
spokeanywhere/
├── spoke/                    # Main source code
│   ├── App/                  # Entry points
│   ├── Core/                 # Business logic by domain
│   │   ├── Audio/            # Audio capture
│   │   ├── LLM/              # AI integrations
│   │   ├── Transcription/    # Speech-to-text
│   │   ├── Screenshot/       # Screenshot capture
│   │   └── LiveCaption/      # Real-time captions
│   ├── Services/             # Global singletons
│   ├── UI/                   # SwiftUI views
│   │   └── Theme/            # DesignTokens
│   └── Resources/            # Assets, models
├── docs/                     # Documentation
│   ├── architecture/         # Architecture docs
│   ├── style/                # Design system
│   └── memo/                 # Development notes
└── CLAUDE.md                 # AI assistant guidelines
```

See [docs/architecture/OVERVIEW.md](docs/architecture/OVERVIEW.md) for detailed architecture.

## Code Standards

### Styling with DesignTokens

**All UI styling MUST use DesignTokens** - no hardcoded values allowed.

```swift
// Correct
.foregroundColor(DesignTokens.Colors.textPrimary)
.cornerRadius(DesignTokens.CornerRadius.lg)
.padding(DesignTokens.Spacing.md)

// Incorrect - will be rejected in PR review
.foregroundColor(Color.white.opacity(0.9))
.cornerRadius(14)
.padding(16)
```

Reference: `spoke/UI/Theme/DesignTokens.swift`

### Swift Style Guide

- **Naming**: Use clear, descriptive names following Swift API Design Guidelines
- **File organization**: One primary type per file, extensions in same file or `+Extension.swift`
- **Line length**: Keep under 120 characters
- **SwiftLint**: All code must pass SwiftLint checks

```bash
# Run SwiftLint
swiftlint
```

### Logging

Use structured logging with `os.Logger`:

```swift
import os

private let logger = Logger(subsystem: "com.spokeanywhere", category: "MyModule")

// Usage
logger.debug("Processing started")
logger.info("User action: \(action)")
logger.error("Failed to load: \(error.localizedDescription)")
```

### Error Handling

- Use Swift's error handling (`throws`, `Result`, `async throws`)
- Provide meaningful error messages
- Log errors appropriately
- Never silently swallow errors

### Memory Management

- Use `[weak self]` in closures to prevent retain cycles
- Avoid force unwraps (`!`) - use `guard let` or optional chaining
- Clean up resources in `deinit` or cancellation handlers

## Development Workflow

### Branch Naming

```
feature/short-description
fix/issue-description
refactor/component-name
docs/documentation-topic
```

### Commit Messages

Follow conventional commits format:

```
<type>: <description>

[optional body]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `perf`: Performance improvement
- `docs`: Documentation
- `test`: Tests
- `chore`: Maintenance

Examples:
```
feat(live-caption): add vocabulary highlighting
fix(screenshot): resolve memory leak in capture service
refactor(services): extract DI container
```

### Development Commands

```bash
# Build and run (recommended)
cd spoke && ./dev.sh

# Build only
cd spoke && swift build

# Run tests
cd spoke && swift test

# Lint
swiftlint

# Clean build
cd spoke && swift package clean
```

## Pull Request Process

### Before Submitting

1. **Test your changes locally**
   ```bash
   cd spoke && swift build && swift test
   ```

2. **Run SwiftLint**
   ```bash
   swiftlint
   ```

## Quality Playbook

For CI mapping and troubleshooting flow (build/test/concurrency/sanitizer), see:

- `docs/quality-playbook.md`

3. **Verify DesignTokens usage**
   - No hardcoded colors, spacing, or corner radii
   - All new UI uses DesignTokens

4. **Update documentation** if needed

### PR Template

```markdown
## Summary
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Refactoring
- [ ] Documentation

## Changes Made
- Change 1
- Change 2

## Testing
- [ ] Tested locally with `./dev.sh`
- [ ] All existing tests pass
- [ ] Added new tests (if applicable)

## Screenshots
(if UI changes)

## Checklist
- [ ] Code follows project style guidelines
- [ ] DesignTokens used for all UI styling
- [ ] No hardcoded values
- [ ] SwiftLint passes
- [ ] Documentation updated
```

### Review Process

1. Submit PR against `main` branch
2. Automated checks must pass (build, lint)
3. At least one code review approval required
4. Squash and merge when approved

## Testing

### Running Tests

```bash
cd spoke && swift test
```

### Test Organization

```
spoke/Tests/
├── Unit/           # Unit tests
├── Integration/    # Integration tests
└── Fixtures/       # Test data
```

### Writing Tests

```swift
import XCTest
@testable import Spoke

final class MyServiceTests: XCTestCase {
    var sut: MyService!

    override func setUp() {
        super.setUp()
        sut = MyService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testFeatureBehavior() {
        // Given
        let input = "test"

        // When
        let result = sut.process(input)

        // Then
        XCTAssertEqual(result, expected)
    }
}
```

## Questions?

- Check existing [documentation](docs/)
- Review [CLAUDE.md](CLAUDE.md) for AI assistant guidelines
- Open an issue for questions or feature requests

---

Thank you for contributing to SpokenAnyWhere!
