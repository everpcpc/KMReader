# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## Project Overview

**KMReader** is a native SwiftUI client for [Komga](https://github.com/gotson/komga), a self-hosted digital comic/book library manager. The app supports iOS 17.0+, macOS 14.0+, and tvOS 17.0+ with Swift 5.9+ and Xcode 15.0+.

Key features:

- Multi-server vault with password or API key authentication
- Cloud-drive-like offline with background downloads, Live Activities on iOS, and per-series policies
- Browse and dashboards with search, filters, grid/list layouts, and per-library sections
- Readers: DIVINA (LTR/RTL/vertical/Webtoon), spreads, zoom, tap zones, transitions, and exports
- EPUB with custom fonts/themes, pagination, TOC navigation, and incognito mode
- Admin tools for metadata editing, scans, task management, live SSE metrics, and log viewer
- Three-tier caches (pages, books, thumbnails) with adjustable limits and cleanup

## Commands

### Build Commands

```bash
# Build for specific platforms
# Used for local builds
make build-ios          # Build for iOS device
make build-macos        # Build for macOS
make build-tvos         # Build for tvOS device

# CI-friendly builds (no code signing, simulator targets)
# Used by the CI workflow, do not use for local builds.
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

### Format

```bash
make format             # Format code
```

### Localization

```bash
make localize           # Update localizations
```

```bash
# List missing translations
./misc/translate.py list

# Update translations for a key
./misc/translate.py update <key>  --zh-hans <zh-hans> --zh-hant <zh-hant> --de <de> --en <en> --fr <fr> --ja <ja> --ko <ko>
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

## Architecture

### Tech Stack

- **UI**: SwiftUI over UIKit/AppKit, use UIKit/AppKit as less as possible.
- **State**: `@Observable` pattern (not `ObservableObject`)
- **Persistence**: SwiftData for profiles/libraries/fonts/series/books/collections/read lists/dashboard caches, UserDefaults via `AppConfig`
- **Networking**: Centralized `APIClient` with feature-specific services
- **Real-time**: Server-Sent Events (SSE) via `SSEService`
- **Error Handling**: Route all user-visible errors through `ErrorManager.shared` (Core/Storage/Errors/)
- **Logging**: All logging goes through `AppLogger` with OSLog subsystems and categories

### Project Structure

```
KMReader/
├── MainApp.swift              # Entry point, SwiftData setup, environment injection
├── ContentView.swift          # Main navigation, login/tab switching
├── MainSplitView.swift        # Split view shell for macOS/iPad
├── PhoneTabView.swift         # iPhone tab shell (iOS 18+)
├── TVTabView.swift            # tvOS tab shell (tvOS 18+)
├── OldTabView.swift           # Legacy tab shell (iOS/tvOS < 18)
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
│   │   ├── Author/            # Author models
│   │   ├── Book/              # Book, BookPage, BookMetadata, ReadProgress, DownloadStatus
│   │   ├── Collection/        # Collection
│   │   ├── Common/            # TabItem, ThemeColor, BrowseContentType, BrowseLayoutMode, Metrics
│   │   ├── Dashboard/         # Dashboard sections and metrics
│   │   ├── History/           # Reading history models
│   │   ├── Library/           # KomgaLibrary, Library
│   │   ├── Reader/            # CustomFont, Page, PageLayout, ReadingDirection, ReaderBackground
│   │   ├── ReadList/          # ReadList
│   │   ├── Series/            # Series, SeriesMetadata, SeriesStatus, SeriesSortField
│   │   ├── SSE/               # SSEEvent
│   │   ├── Sync/              # PendingProgress
│   │   └── WebPub/            # WebPub models
│   ├── Services/              # Domain services
│   │   ├── Auth/              # AuthService
│   │   ├── Book/              # BookService, KomgaBookStore
│   │   ├── Series/            # SeriesService
│   │   ├── Collection/        # KomgaCollectionStore
│   │   ├── History/           # HistoryService
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
│       ├── Book/              # BookFilterView, BookEditSheet, BookBrowseOptionsSheet
│       ├── Series/            # Series detail and filtering views
│       ├── Collection/        # CollectionEditSheet, CollectionSeriesFilterView, CollectionSortView
│       ├── ReadList/          # ReadListEditSheet, ReadListBookFilterView, ReadListSortView
│       ├── OneShot/           # One-shot detail and edit views
│       ├── Reader/            # DivinaReaderView, EpubReaderView, BookReaderView, ReaderControlsView
│       │   ├── AppKit/        # KeyboardEventHandler (macOS)
│       │   ├── Models/        # EpubReaderPreferences
│       │   ├── Sheets/        # CustomFontsSheet, EpubPreferencesSheet
│       │   ├── PageImage/     # SinglePageImageView, ZoomableImageContainer
│       │   └── Webtoon/       # Webtoon reader components
│       ├── Browse/            # Browse views for various content types
│       ├── Components/        # Shared view components
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
- `ContentView.swift`: Chooses onboarding (`LandingView`) or authenticated shells
  - macOS and iPad: `MainSplitView`
  - iPhone: `PhoneTabView` (iOS 18+) or `OldTabView`
  - tvOS: `TVTabView` (tvOS 18+) or `OldTabView`
  - Shows `SplashView` during initialization (`InstanceInitializer`)
- Reacts to `@AppStorage` flags (`isLoggedIn`, `enableSSE`, `isOffline`)
- Reader presentation: `ReaderOverlay` on iOS/tvOS, `ReaderWindowManager` + `ReaderWindowView` on macOS
- On startup: loads current user, sets offline mode, connects SSE if enabled
- On reconnect: syncs pending progress and resumes offline downloads
- On active scene: updates instance last-used and resumes offline syncs if online

**State & Persistence**

- **SwiftData**: `KomgaInstance`, `KomgaLibrary`, `KomgaSeries`, `KomgaBook`, `KomgaCollection`, `KomgaReadList`, `CustomFont`, `PendingProgress` with dedicated stores
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

1. **Comments**: Minimal, in English only
2. **Commit messages**: Concise, clear, semantic format, in English
3. **SwiftUI over UIKit/AppKit**: Prefer SwiftUI exclusively
4. **No inline Binding**: Avoid inline Binding usage
5. **No confirmationDialog**: Do not use confirmationDialog
6. **One type per file**: Every struct or class in a separate file
7. **@Observable over ObservableObject**: Use @Observable pattern for view models
8. **@AppStorage over UserDefaults**: In views use @AppStorage; elsewhere use AppConfig, UserDefaults is forbidden in files except AppConfig.swift
9. **Computed properties in view bodies**: Avoid stored variables in view bodies
10. **Platform differences**: Use `PlatformHelper` and `#if os(...)` blocks

Additional patterns:

- Inject view models through SwiftUI environment (register in `MainApp`)
- SSE callbacks are single-assignment closures; implement dispatchers if multiple components need the same event
- Clearing caches/server data must go through `CacheManager` and SwiftData stores
- New API endpoints belong in appropriate service; keep request-building out of views
- Dashboard/library selections stored via `LibraryManager` and related managers
- All logging goes through `AppLogger` with OSLog subsystems and categories
- Xcode project uses folder references (not groups); adding/removing files does not require editing `project.pbxproj`
- Do not use xcodebuild directly, use the Makefile instead.
- Translation all supported languages, refer to ../komga/komga-webui/src/locales/ if available.

## Important Files

- `openapi.json`: Komga REST API contract
- `AGENTS.md`: Comprehensive contributor guide
- `Makefile`: Build automation commands
- `misc/`: Build scripts (archive.sh, release.sh, bump.sh, bump-version.sh, artifacts.sh)

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
