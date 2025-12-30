# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**KMReader** is a native SwiftUI client for [Komga](https://github.com/gotson/komga), a self-hosted digital comic/book library manager. The app supports iOS 17.0+, macOS 14.0+, and tvOS 17.0+ with Swift 5.9+ and Xcode 15.0+.

Key features:

- Multi-server management with password/API key authentication
- Multiple reader types: DIVINA (comics), EPUB, and Webtoon (vertical scroll)
- Dashboard browsing, filtering, and search with customizable layouts
- Offline downloads with background support and Live Activities (iOS)
- Admin tools (metadata editing, task management, SSE metrics)
- Multi-tier caching system (pages, books, thumbnails) with configurable budgets

## Commands

### Build Commands

```bash
# Build for specific platforms
make build-ios          # Build for iOS device
make build-macos        # Build for macOS
make build-tvos         # Build for tvOS device

# CI-friendly builds (no code signing, simulator targets)
make build-ios-ci       # iOS simulator
make build-macos-ci     # macOS without signing
make build-tvos-ci      # tvOS simulator

# Other build commands
make build              # Build all platforms
make release            # Archive and export all platforms
make artifacts          # Prepare IPA/DMG for GitHub Release
make clean              # Remove archives, exports, and artifacts
```

### Version Management

```bash
make bump               # Increment CURRENT_PROJECT_VERSION
make minor              # Increment minor version (MARKETING_VERSION)
make major              # Increment major version (MARKETING_VERSION)
```

### Development

```bash
open KMReader.xcodeproj # Open project in Xcode
```

## Testing & Validation

**Important**: There are no XCTest targets in this repository.

Validate changes by:

1. Building all relevant targets (`make build-ios`, `make build-macos`, `make build-tvos` or CI variants)
2. Manual testing: login/logout, server switching, dashboard refresh, SSE auto-refresh, reader opening/closing, cache clearing
3. Watch Xcode Console filtered by subsystem `Komga` with categories `API`, `SSE`, or `ReaderViewModel`

Test with:

- **iOS Simulator**: iPhone 11 Pro Max or iPad Air 13-inch (M2)
- **macOS**: Local machine
- **tvOS**: Simulator

Linting note from project rules: "Lint is not stable for swift, run `make build-ios` before to ensure there's really a problem."

## Architecture

### Tech Stack

- **UI**: SwiftUI exclusively (avoid UIKit/AppKit)
- **State**: `@Observable` pattern (not `ObservableObject`)
- **Persistence**: SwiftData for profiles/libraries/fonts, UserDefaults via `AppConfig`
- **Networking**: Centralized `APIClient` with feature-specific services
- **Real-time**: Server-Sent Events (SSE) via `SSEService`

### Project Structure

```
KMReader/
├── MainApp.swift              # Entry point, SwiftData setup, environment injection
├── ContentView.swift          # Main navigation, login/tab switching
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift    # Centralized HTTP, auth, logging
│   │   └── SSEService.swift   # Server-sent events, reconnect logic
│   └── Storage/
│       ├── AppConfig.swift    # UserDefaults-backed preferences
│       ├── AppLogger.swift    # Centralized logging
│       ├── DatabaseOperator.swift
│       ├── LogStore.swift     # Log persistence
│       ├── ManagementService.swift
│       ├── Cache/             # CacheManager, ImageCache, BookFileCache, ThumbnailCache
│       └── Errors/            # AppErrorType, ErrorManager
├── Features/
│   ├── Models/                # DTOs, SwiftData models
│   │   ├── Auth/              # KomgaInstance, User, AuthenticationMethod, ApiKey
│   │   ├── Book/              # Book, BookPage, BookMetadata, ReadProgress, DownloadStatus
│   │   ├── Series/            # Series, SeriesMetadata, SeriesStatus, SeriesSortField
│   │   ├── Collection/        # Collection
│   │   ├── ReadList/          # ReadList
│   │   ├── Library/           # KomgaLibrary, Library
│   │   ├── Reader/            # CustomFont, Page, PageLayout, ReadingDirection, ReaderBackground
│   │   ├── Common/            # TabItem, ThemeColor, BrowseContentType, BrowseLayoutMode, Metrics
│   │   └── SSE/               # SSEEvent
│   ├── Services/              # Domain services
│   │   ├── Auth/              # AuthService
│   │   ├── Book/              # BookService, KomgaBookStore
│   │   ├── Series/            # SeriesService
│   │   ├── Collection/        # KomgaCollectionStore
│   │   ├── ReadList/          # KomgaReadListStore
│   │   ├── Library/           # LibraryService, LibraryManager, LibraryMetricsLoader
│   │   ├── Reader/            # CustomFontStore
│   │   ├── Offline/           # OfflineManager, BackgroundDownloadManager, DownloadProgressTracker, LiveActivityManager
│   │   ├── Sync/              # SyncService, ProgressSyncService, InstanceInitializer
│   │   └── Store/             # StoreManager
│   ├── ViewModels/            # @Observable state objects
│   │   ├── Auth/, Book/, Series/, Collection/, ReadList/, Reader/, Common/
│   └── Views/                 # SwiftUI views by feature
│       ├── Auth/              # LandingView
│       ├── Dashboard/         # DashboardView, DashboardSectionView, DashboardSectionDetailView
│       ├── Book/              # BookFilterView, BookEditSheet, BookDownloadSheet, BookBrowseOptionsSheet
│       ├── Series/            # Series detail and filtering views
│       ├── Collection/        # CollectionEditSheet, CollectionSeriesFilterView, CollectionSortView
│       ├── ReadList/          # ReadListEditSheet, ReadListBookFilterView, ReadListSortView
│       ├── Reader/            # DivinaReaderView, EpubReaderView, BookReaderView, ReaderControlsView
│       │   ├── AppKit/        # KeyboardEventHandler (macOS)
│       │   ├── Models/        # EpubReaderPreferences
│       │   ├── Sheets/        # CustomFontsSheet, EpubPreferencesSheet
│       │   ├── PageImage/     # SinglePageImageView, ZoomableImageContainer
│       │   └── Webtoon/       # Webtoon reader components
│       ├── Browse/            # Browse views for various content types
│       └── Settings/          # SettingsView, per-category settings sheets
└── Shared/
    ├── Extensions/            # View extensions, helpers
    ├── Helpers/               # FileNameHelper, LanguageCodeHelper, PlatformHelpers
    └── UI/                    # Reusable UI components
        ├── ThumbnailImage.swift
        ├── BrowseStateView.swift
        ├── NotificationOverlay.swift
        ├── ReadingProgressBar.swift
        └── ...                # Filter chips, info rows, layout pickers, etc.
```

### Key Flows

**App Lifecycle**

- `MainApp.swift`: Loads SwiftData schema, configures stores, registers iOS AppDelegate for background downloads
- `ContentView.swift`: Decides between onboarding (`LandingView`) and authenticated tabs
  - iOS 18.0+, macOS 15.0+, tvOS 18.0+: `MainTabView` (modern tab navigation)
  - Earlier versions: `OldTabView` (compatibility fallback)
  - Shows `SplashView` during initialization (`InstanceInitializer`)
- Reacts to `@AppStorage` flags (`isLoggedIn`, `enableSSE`, `themeColorHex`, `isOffline`)
- Reader presentation: `.fullScreenCover` on iOS/tvOS, `ReaderWindowManager` for separate windows on macOS
- On startup: loads current user, checks server reachability, sets offline mode, connects SSE if enabled

**State & Persistence**

- **SwiftData**: `KomgaInstance`, `KomgaLibrary`, `KomgaSeries`, `KomgaBook`, `KomgaCollection`, `KomgaReadList`, `CustomFont` with dedicated stores
- **AppConfig**: Centralizes UserDefaults (server URL, tokens, SSE toggles, reader preferences, cache budgets, API timeout/retry settings)
- **Caches**: Multi-tier caching scoped per Komga instance via `CacheNamespace` (managed by `CacheManager`)
- Use `@AppStorage` in views, `AppConfig` elsewhere
- When building JSON strings for storage or cache keys, use `JSONSerialization` with `sortedKeys` to keep raw values stable and prevent redundant updates.

**Networking**

- `APIClient.swift`: Authenticated requests, JSON decoding, OSLog logging, configurable timeout and retry
- Feature services mirror `openapi.json` endpoints with pagination/filtering
- Services organized by domain: `AuthService`, `BookService`, `SeriesService`, `LibraryService`, etc.
- Authentication: `AuthService` + SwiftData `KomgaInstance` stores + `AppConfig`

**Real-time Updates**

- `SSEService`: Connects to `/sse/v1/events`, exposes per-entity callbacks
- View models register closures to refresh on events
- Dashboard debounces updates, pauses while reader is open

**Error Handling**

- Route all user-visible errors through `ErrorManager.shared` (Core/Storage/Errors/)
- Use `ErrorManager.notify` for transient success messages
- Errors appear in `ContentView` overlay via `NotificationOverlay`

**Offline & Background Downloads**

- `OfflineManager`: Manages offline book downloads and storage
- `BackgroundDownloadManager`: Handles background URLSession downloads (iOS)
- `DownloadProgressTracker`: Tracks download progress across the app
- `LiveActivityManager`: Shows download progress in Live Activities (iOS)

**Sync & Initialization**

- `SyncService`: Syncs data between server and local SwiftData
- `ProgressSyncService`: Syncs read progress to server
- `InstanceInitializer`: Initializes app state on startup and server switch

## Coding Conventions

From `.cursor/rules/default.mdc`:

1. **Comments**: Minimal, in English only
2. **Commit messages**: Concise, clear, semantic format, in English
3. **SwiftUI over UIKit/AppKit**: Prefer SwiftUI exclusively
4. **No inline Binding**: Avoid inline Binding usage
5. **No confirmationDialog**: Do not use confirmationDialog
6. **One type per file**: Every struct or class in a separate file
7. **@Observable over ObservableObject**: Use @Observable pattern for view models
8. **@AppStorage over UserDefaults**: In views use @AppStorage; elsewhere use AppConfig
9. **Computed properties in view bodies**: Avoid stored variables in view bodies
10. **Platform differences**: Use `PlatformHelper` and `#if os(...)` blocks

Additional patterns:

- Inject view models through SwiftUI environment (register in `MainApp`)
- SSE callbacks are single-assignment closures; implement dispatchers if multiple components need the same event
- Clearing caches/server data must go through `CacheManager` and SwiftData stores
- New API endpoints belong in appropriate service; keep request-building out of views
- Dashboard/library selections stored via `LibraryManager` and related managers
- All logging goes through `AppLogger` with OSLog subsystems and categories

## Important Files

- `/Users/everpcpc/src/KMReader/openapi.json`: Komga REST API contract
- `/Users/everpcpc/src/KMReader/AGENTS.md`: Comprehensive contributor guide
- `/Users/everpcpc/src/KMReader/Makefile`: Build automation commands
- `/Users/everpcpc/src/KMReader/misc/`: Build scripts (archive.sh, release.sh, bump.sh, bump-version.sh, artifacts.sh)

## Reference

- **API compatibility**: Requires Komga 1.19.0+ (API v1 and v2)
- **Platforms**:
  - iOS 17.0+ (all features: DIVINA, EPUB, Webtoon readers, background downloads, Live Activities)
  - macOS 14.0+ (DIVINA, EPUB, Webtoon readers, separate reader windows)
  - tvOS 17.0+ (DIVINA reader only, simplified UI)
- **Reader availability**:
  - DIVINA: All platforms
  - EPUB: iOS and macOS only
  - Webtoon: iOS and macOS only
- **License**: MIT
