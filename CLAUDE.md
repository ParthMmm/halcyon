# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Halcyon is a macOS app built with Swift/SwiftUI to manage Apple Music playlist folders. It allows users to view, create, rename, delete, and move playlists between folders. The app provides a full-featured interface for playlist and folder management within the Music app.

## Build & Run Commands

### Building the Project
```bash
# Build the project
xcodebuild -scheme halcyon -destination 'platform=macOS' build

# Clean build folder
xcodebuild -scheme halcyon clean

# Or use Xcode shortcuts:
# Cmd+B - Build
# Cmd+Shift+K - Clean Build Folder
# Cmd+R - Build and Run
```

### Running the App
- The app must be run from Xcode (Cmd+R)
- **Required**: macOS Music app must be running
- **Required**: Grant automation permissions when prompted (System Settings > Privacy & Security > Automation)

## Architecture: MVVM Pattern

### Data Flow
1. **View** (SwiftUI) → **ViewModel** (`@Published` bindings) → **Service** (AppleScript) → **Music app**
2. Music app response → Service → ViewModel → View updates

### Layer Responsibilities

**Models/** (`Folder.swift`, `Playlist.swift`)
- Pure data structures (structs)
- Must be `Identifiable`, `Codable`, `Equatable`, `Hashable`
- No business logic
- `Playlist` no longer has `position` property (ordering not supported by AppleScript)

**Services/** (`MusicScriptService.swift`)
- **Critical**: All Music app communication via NSAppleScript
- Throws `MusicScriptError` for error handling
- Methods: `getFolders()`, `getPlaylists(in:)`, `createPlaylist()`, `createFolder()`, `renamePlaylist()`, `deletePlaylist()`, `movePlaylist()`

**ViewModels/** (`MusicLibraryViewModel.swift`)
- `@MainActor` required for all ViewModels
- `@Published` properties for reactive UI updates
- State: `folders`, `selectedFolder`, `isLoading`, `errorMessage`
- Injects `MusicScriptService` for testability
- Manages CRUD operations for playlists and folders

**Views/** (`ContentView.swift`, `FolderListView.swift`, `PlaylistListView.swift`)
- SwiftUI views observing ViewModel via `@ObservedObject` or `@StateObject`
- `ContentView`: Main layout with `NavigationSplitView`
- `FolderListView`: Sidebar displaying folders with "New Folder" button
- `PlaylistListView`: Detail view with context menus for playlist management

## AppleScript Integration - Critical Guidelines

### Memory Safety Rules
**NEVER** directly access `NSAppleEventDescriptor` properties that are non-Optional:
- ❌ `descriptor.booleanValue` - causes EXC_BAD_ACCESS crash
- ❌ `descriptor.int32Value` - causes EXC_BAD_ACCESS crash
- ✅ `descriptor.stringValue` - safe (Optional)
- ✅ `descriptor.atIndex(i)` - safe (Optional)

### Safe Descriptor Handling Pattern
```swift
private func convertDescriptor(_ descriptor: NSAppleEventDescriptor) -> Any? {
    // 1. Check for arrays first
    if descriptor.numberOfItems > 0 {
        // Safely iterate with atIndex()
    }

    // 2. Use stringValue and parse to other types
    if let stringValue = descriptor.stringValue {
        // Parse numbers from string representation
        if let intValue = Int(stringValue) {
            return intValue
        }
        return stringValue
    }

    return nil
}
```

### AppleScript Return Types
- AppleScript should return **strings** for booleans (`"true"` / `"false"`)
- Arrays are returned as lists that must be converted recursively
- See `MusicScriptService.convertDescriptor()` for the canonical implementation

## Common Patterns

### Adding New Music App Operations
1. Add method to `MusicScriptService` with AppleScript
2. Add error handling with `MusicScriptError`
3. Add corresponding method to `MusicLibraryViewModel`
4. Update UI in relevant View with `@Published` binding

### Supported Operations
- ✅ Create/rename/delete playlists and folders
- ✅ Move playlists between folders
- ✅ View playlists in folders
- ✅ Sort playlists (alphabetical/reverse/original order)
- ❌ Playlist ordering within folders (AppleScript limitation)

### Testing AppleScript Changes
- Always test with Music app running
- Check for automation permissions
- Use `print()` statements in `executeScript()` to debug AppleScript errors
- AppleScript errors appear as `NSDictionary` in error parameter

## Key Constraints

- **macOS only**: Uses NSAppleScript which is macOS-specific
- **Music app dependency**: All folder/playlist operations require Music app to be running
- **Permissions**: Requires "Automation" permission for "Music" app
- **AppleScript limitations**: No direct playlist position control in Music's AppleScript API - playlists maintain Music app's natural order

## File Import Requirements

- `MusicScriptService.swift`: Only `import Foundation` (no Carbon)
- `MusicLibraryViewModel.swift`: Must import both `SwiftUI` and `Combine`
- All other files: Standard SwiftUI imports
