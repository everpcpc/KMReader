# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## Project Overview

**KMReader** is a native SwiftUI client for [Komga](https://github.com/gotson/komga), a self-hosted digital comic/book library manager. The app supports iOS 17.0+, macOS 14.0+, and tvOS 17.0+ with Swift 6.0+ and Xcode 15.0+.

### Readers

- **DIVINA Reader** (iOS, macOS, tvOS): LTR/RTL/vertical/Webtoon modes with spreads, zoom, customizable tap zones, and page curl transitions. Live Text support with shake-to-toggle on iOS.
- **EPUB Reader** (iOS, macOS): Native engine with custom font importing (.ttf/.otf), theme presets, multi-column layouts, and nested TOC navigation.
- **Per-Book Preferences**: Save reading direction, page layout, and theme settings per book.
- **Incognito Mode**: Read without saving progress to server.

### Offline & Downloads

- **Background Downloads**: URLSession-based downloads with Live Activities on iOS.
- **Series Policies**: Manual, unread-only, unread+cleanup, or all books per series.
- **Offline Mode**: Full reader functionality with downloaded content. Progress syncs when reconnected.
- **Three-Tier Caching**: Pages, book files, and thumbnails with adjustable limits and auto-cleanup.

### Browse & Dashboards

- **Dynamic Dashboards**: Keep Reading, On Deck, Recently Added, Recently Updated with real-time SSE updates.
- **Advanced Filters**: Search with metadata filters (authors, genres, tags, publishers) using all/any logic.
- **Grid/List Layouts**: Multiple density options (compact, standard, comfortable).
- **Library Filtering**: Browse per-library or across all libraries.

### Multi-Server Vault

- **Unlimited Servers**: Save multiple Komga instances with password or API key authentication.
- **Quick Switching**: Instant server switching with isolated data per instance.
- **API Key Management**: Create, view, and revoke API keys.

### Admin Tools

- **Metadata Editing**: Edit series, books, collections, and read lists.
- **Library Management**: Create, edit, scan libraries with directory browser.
- **Task Management**: Monitor and cancel server tasks with live metrics.
- **Logs Viewer**: View and export app logs with filtering.

### Platform-Specific

- **iOS**: Live Activities, background downloads, page curl transitions, shake gestures.
- **macOS**: Separate reader windows, comprehensive keyboard shortcuts, keyboard help overlay.
- **tvOS**: Remote control navigation, TV-optimized interface (DIVINA only).

## Commands

### Build Commands

All build and run commands use `misc/xcode.py` internally. The script manages device selection and persists preferences in `devices.json`.

For iOS and tvOS builds, the script will select a specific simulator (using saved preference or prompting for selection).

```bash
# Build for specific platforms
# Builds for a specific simulator (will use saved preference or prompt for selection)
make build-ios          # Build for iOS simulator
make build-macos        # Build for macOS
make build-tvos         # Build for tvOS simulator

# Other build commands
make build              # Build all platforms
make release            # Archive and export all platforms
make artifacts          # Prepare IPA/DMG for GitHub Release
make clean              # Remove archives, exports, and artifacts
```

Build execution rule:
- Do not run multiple `make build-*` commands in parallel. `xcodebuild` shares the same DerivedData build database and parallel runs may fail with database lock errors.
- Prefer `make build` for full validation.
- If platform-specific builds are required, run `make build-ios`, `make build-macos`, and `make build-tvos` sequentially.

### Run Commands

Run commands support device selection with preferences stored in `devices.json`.

```bash
# List available devices (simulators and physical devices)
make list-device

# Run on simulators
make run-ios-sim        # iOS simulator
make run-tvos-sim       # tvOS simulator

# Run on physical devices
make run-ios-device     # iOS device
make run-tvos-device    # tvOS device

# Run on macOS
make run-macos          # Build and run on macOS

# Force device selection (ignore saved preference)
make run-ios-sim-select      # iOS simulator with device selection prompt
make run-ios-device-select   # iOS device with device selection prompt
make run-tvos-sim-select     # tvOS simulator with device selection prompt
make run-tvos-device-select  # tvOS device with device selection prompt

# Direct script usage (alternative to make commands)
python3 misc/xcode.py list                    # List all devices
python3 misc/xcode.py list ios --simulators   # List iOS simulators only
python3 misc/xcode.py build ios               # Build for iOS
python3 misc/xcode.py run ios --simulator     # Run on iOS simulator
python3 misc/xcode.py run ios --device        # Run on iOS device
python3 misc/xcode.py run ios --simulator --select  # Force device selection
```

Device selection behavior:
- **Interactive mode** (terminal): Prompts you to select from available devices and optionally save as default
- **Non-interactive mode** (CI/scripts): Automatically selects the first available device and saves it
- **Saved preference**: If a device is already saved in `devices.json`, it will be used automatically
- **Unavailable saved device**: If the saved device is no longer available, falls back to selection/auto-selection
- **Force selection** (`--select` or `-select` suffix): Always shows device selection prompt, ignoring saved preference

Device preferences are stored in `devices.json` (gitignored) with keys like `ios_simulator`, `ios_device`, `tvos_simulator`, etc.

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

1. Build targets sequentially (prefer `make build`; if needed, run `make build-ios`, `make build-macos`, and `make build-tvos` in order)
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
│   ├── Auth/
│   │   ├── Models/            # KomgaInstance, User, AuthenticationMethod, ApiKey
│   │   ├── Services/          # AuthService
│   │   ├── ViewModels/
│   │   └── Views/             # LandingView
│   ├── Book/
│   │   ├── Models/            # Book, BookPage, BookMetadata, ReadProgress, DownloadStatus
│   │   ├── Services/          # BookService, KomgaBookStore
│   │   ├── ViewModels/
│   │   └── Views/             # BookFilterView, BookEditSheet, BookBrowseOptionsSheet
│   ├── Browse/
│   │   ├── Models/
│   │   └── Views/             # Browse views for various content types
│   ├── Collection/
│   │   ├── Models/            # Collection
│   │   ├── Services/          # KomgaCollectionStore
│   │   ├── ViewModels/
│   │   └── Views/             # CollectionEditSheet, CollectionSeriesFilterView, CollectionSortView
│   ├── Dashboard/
│   │   ├── Models/            # Dashboard sections and metrics
│   │   └── Views/             # DashboardView, DashboardSectionView, DashboardSectionDetailView
│   ├── Filesystem/
│   │   ├── Models/
│   │   └── Services/
│   ├── History/
│   │   ├── Models/            # Reading history models
│   │   └── Services/
│   ├── Library/
│   │   ├── Models/            # KomgaLibrary, Library
│   │   └── Services/          # LibraryService, LibraryManager, LibraryMetricsLoader
│   ├── Offline/
│   │   ├── Services/          # OfflineManager, BackgroundDownloadManager, DownloadProgressTracker, LiveActivityManager
│   │   └── Views/
│   ├── OneShot/
│   │   └── Views/             # One-shot detail and edit views
│   ├── Reader/
│   │   ├── Models/            # CustomFont, Page, PageLayout, ReadingDirection, ReaderBackground
│   │   ├── Services/          # CustomFontStore
│   │   ├── ViewModels/
│   │   └── Views/             # DivinaReaderView, EpubReaderView, BookReaderView, ReaderControlsView
│   │       ├── Models/        # EpubReaderPreferences
│   │       ├── Sheets/        # CustomFontsSheet, EpubPreferencesSheet
│   │       ├── PageImage/     # SinglePageImageView, ZoomableImageContainer
│   │       └── Webtoon/       # Webtoon reader components
│   ├── ReadList/
│   │   ├── Models/            # ReadList
│   │   ├── Services/          # KomgaReadListStore
│   │   ├── ViewModels/
│   │   └── Views/             # ReadListEditSheet, ReadListBookFilterView, ReadListSortView
│   ├── Series/
│   │   ├── Models/            # Series, SeriesMetadata, SeriesStatus, SeriesSortField
│   │   ├── Services/          # SeriesService
│   │   ├── ViewModels/
│   │   └── Views/             # Series detail and filtering views
│   ├── Settings/
│   │   └── Views/             # SettingsView, per-category settings sheets
│   ├── Server/
│   │   └── Views/
│   ├── Sync/
│   │   ├── Models/            # PendingProgress
│   │   └── Services/          # SyncService, ProgressSyncService, InstanceInitializer
│   ├── Store/
│   │   └── Services/          # StoreManager
│   ├── Author/
│   │   └── Models/            # Author models
│   ├── WebPub/
│   │   └── Models/            # WebPub models
│   ├── SSE/
│   │   └── Models/            # SSEEvent
│   └── Referential/
│       └── Services/
└── Shared/
    ├── Extensions/            # View extensions, helpers
    ├── Foundation/
    │   ├── Models/            # TabItem, ThemeColor, BrowseContentType, BrowseLayoutMode, Metrics
    │   └── ViewModels/
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
