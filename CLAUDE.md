# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Fuckify is a sexual health application meant for tracking partners, sexual encounters, durations, activities, and more.

Fuckify is an iOS application built with SwiftUI and SwiftData, targeting iOS 26.0+. It's a single-target Xcode project using Xcode 26.0.1.

## Build and Run Commands

**Building the project:**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build
```

**Building for release:**
```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Release build
```

**Opening in Xcode:**
```bash
open Fuckify.xcodeproj
```

**Running tests (when added):**
```bash
xcodebuild test -project Fuckify.xcodeproj -scheme Fuckify -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

### Data Layer
- **SwiftData**: Primary persistence framework using `ModelContainer` configured in `FuckifyApp.swift:13-24`
- **Models**: Located in `Fuckify/` directory
  - `Item.swift`: Base SwiftData model with `@Model` macro
- **Storage**: Persistent storage (not in-memory) configured via `ModelConfiguration`
- **Model Container**: Shared instance created at app launch in `FuckifyApp.swift:13` and injected into the environment at line 30

### UI Layer
- **SwiftUI**: Modern declarative UI framework
- **Navigation**: Uses `NavigationSplitView` for master-detail interface in `ContentView.swift:16`
- **Data Binding**: `@Query` macro for reactive SwiftData queries in `ContentView.swift:13`
- **Environment**: `@Environment(\.modelContext)` for accessing SwiftData context in `ContentView.swift:12`

### Cloud Integration
- **CloudKit**: Enabled via entitlements in `Fuckify.entitlements:7-12`
- **Push Notifications**: Remote notifications enabled in `Info.plist:5-8` for background sync
- **Environment**: Currently set to development mode in `Fuckify.entitlements:6`

## Swift Configuration

- **Swift Version**: 5.0
- **Actor Isolation**: `MainActor` as default (line 167 in project.pbxproj)
- **Concurrency**: Approachable concurrency enabled
- **Language Features**: Member import visibility and strict concurrency checking enabled

## Development Notes

- **Bundle ID**: `baby.safi.Fuckify` (project.pbxproj:163)
- **Team ID**: 8ZAQVXT82R
- **Target Devices**: iPhone and iPad (Universal)
- **Previews**: SwiftUI previews are enabled and configured for in-memory model containers in views

## File Structure

```
Fuckify/
├── Fuckify.xcodeproj/       # Xcode project configuration
└── Fuckify/                 # Source code directory
    ├── FuckifyApp.swift     # App entry point and ModelContainer setup
    ├── ContentView.swift    # Main UI view with navigation
    ├── Item.swift           # SwiftData model definitions
    ├── Assets.xcassets/     # App assets and images
    ├── Info.plist           # App configuration (background modes)
    └── Fuckify.entitlements # Capabilities (CloudKit, push notifications)
```

## Code Signing

Code signing is set to Automatic with development team 8ZAQVXT82R. Ensure the correct team is selected in Xcode if modifying signing settings.
