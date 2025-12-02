# Agent Guidelines for Halcyon

## Build/Lint/Test Commands
- **Build**: `xcodebuild -scheme halcyon -destination 'platform=macOS' build`
- **Clean**: `xcodebuild -scheme halcyon clean`
- **Test Suite**: `xcodebuild -scheme halcyon -destination 'platform=macOS' test`
- **Single Test**: `xcodebuild -scheme halcyon -destination 'platform=macOS' test -only-testing:halcyonTests/ClassName/testMethodName`
- **Run**: Must use Xcode (Cmd+R). Music app must be running with automation permissions granted.

## Code Style & Conventions
- **Imports**: MusicScriptService: `import Foundation` only (NO Carbon). ViewModels: `import SwiftUI` and `import Combine`. Views: `import SwiftUI`.
- **Naming**: Structs for Models (Identifiable, Codable, Equatable, Hashable). Classes for ViewModels/Services. PascalCase types, camelCase properties/methods.
- **ViewModels**: ALWAYS mark with `@MainActor`. Use `@Published` for reactive properties. Inject dependencies (e.g., `MusicScriptService`) for testability.
- **Error Handling**: Throw typed errors (e.g., `MusicScriptError`). ViewModels catch and set `errorMessage: String?` for UI display.
- **AppleScript Safety**: NEVER access `descriptor.booleanValue` or `descriptor.int32Value` (causes crashes). Only use `.stringValue` (Optional) or `.atIndex(i)`. See CLAUDE.md for safe patterns.
- **MVVM Flow**: View → ViewModel (`@Published`) → Service (AppleScript) → Music app. No business logic in Models or Views.
- **Comments**: Minimal. Use `// MARK: -` for section headers. Code should be self-documenting.
- **Formatting**: 4-space indentation. Opening braces on same line. `guard` for early returns.
