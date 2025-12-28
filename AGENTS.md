# AGENTS

> Purpose: consistent, safe Codex execution for SpokenAnyWhere (macOS voice + AI productivity app).

## Role & objective
- Role: coding agent for a macOS Swift app (SwiftUI + AppKit).
- Objective: implement changes aligned to PRD/design docs with strong stability, performance, and App Store compliance.

## Constraints (non-negotiable)
- Preserve backward compatibility unless explicitly approved.
- Avoid private APIs; keep App Store compliance in mind.
- UI must use DesignTokens; no hardcoded styling values.
- Run Swift commands from `spoke/` unless otherwise specified.
- Do not claim tests ran if they did not.

## Tech & data
- Stack: Swift 5.9+, SwiftUI + AppKit, SwiftData, AVFoundation, Speech, ScreenCaptureKit.
- Data sources: `docs/`, `docs/memo/`, `docs/memo/memory.csv`, SwiftData store, Keychain.
- Dev tooling: Swift Package Manager, SwiftLint, Codex CLI, Serena MCP.

## Project testing strategy
- Unit/integration: `cd spoke && swift test` (if test targets exist).
- E2E/UI: manual checklist when automation is missing (HUD, Quick Ask, Live Caption, Selection Toolbar, Screenshot).
- Manual/other: `swiftlint` for style checks.
- Build/run: `cd spoke && swift build`, `cd spoke && swift run SpokenAnyWhere`.
- MCP tools: see `docs/mcp-tools.md`.

## E2E loop
E2E loop = plan → issues → implement → test → review → commit → regression.

## Plan & issue generation
- Use the `plan` skill for plan and Issue CSV generation.
- Plans must include: steps, tests, risks, and rollback/safety notes.
- Plan outputs should use CSV format when applicable.

## Issue CSV guidelines
- Required columns: ID, Title, Description, Acceptance, Test_Method, Tools, Dev_Status, Review1_Status, Regression_Status, Files, Dependencies, Notes.
- Status values: TODO | DOING | DONE.
- Follow `issues/README.md`.

## Tool usage
- When a matching MCP tool exists, use it; do not guess or simulate results.
- Prefer the tool specified in the Issue CSV `Tools` column.
- If a tool is unavailable or fails, note it and proceed with the safest alternative.

## Testing policy
- Follow `docs/testing-policy.md` for verification requirements and defaults.

## Safety
- Avoid destructive commands unless explicitly requested.
- Preserve backward compatibility unless asked to break it.
- Never expose secrets; redact if encountered.

## Output style
- Keep responses concise and structured.
- Provide file references with line numbers when editing.
- Always include risks and suggested next steps for non-trivial changes.

<skills_system priority="1">

## Available Skills

<!-- SKILLS_TABLE_START -->
<usage>
When users ask you to perform tasks, check if any of the available skills below can help complete the task more effectively. Skills provide specialized capabilities and domain knowledge.

How to use skills:
- Invoke: Bash("openskills read <skill-name>")
- The skill content will load with detailed instructions on how to complete the task
- Base directory provided in output for resolving bundled resources (references/, scripts/, assets/)

Usage notes:
- Only use skills listed in <available_skills> below
- Do not invoke a skill that is already loaded in your context
- Each skill invocation is stateless
</usage>

<available_skills>

<skill>
<name>algorithmic-art</name>
<description>Creating algorithmic art using p5.js with seeded randomness and interactive parameter exploration. Use this when users request creating art using code, generative art, algorithmic art, flow fields, or particle systems. Create original algorithmic art rather than copying existing artists' work to avoid copyright violations.</description>
<location>project</location>
</skill>

<skill>
<name>build-macos-apps</name>
<description>Build professional native macOS apps in Swift with SwiftUI and AppKit. Full lifecycle - build, debug, test, optimize, ship. CLI-only, no Xcode.</description>
<location>project</location>
</skill>

<skill>
<name>moai-lang-swift</name>
<description>Swift 6+ development specialist covering SwiftUI, Combine, Swift Concurrency, and iOS patterns. Use when building iOS apps, macOS apps, or Apple platform applications.</description>
<location>project</location>
</skill>

<skill>
<name>skill-creator</name>
<description>Guide for creating effective skills. This skill should be used when users want to create a new skill (or update an existing skill) that extends Claude's capabilities with specialized knowledge, workflows, or tool integrations.</description>
<location>project</location>
</skill>

</available_skills>
<!-- SKILLS_TABLE_END -->

</skills_system>
