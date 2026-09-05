# AGENTS.md

This file provides guidance to coding agents working with code in this repository.

## Project Overview

**KMReader** is a native SwiftUI client for [Komga](https://github.com/gotson/komga), a self-hosted digital comic/book library manager. The app supports iOS 17.0+, macOS 14.0+, and tvOS 17.0+ with Swift 6.0+ and Xcode 15.0+.

### Readers

- **DIVINA Reader** (iOS, macOS, tvOS): LTR/RTL/vertical/Webtoon modes with spreads, zoom, customizable tap zones, and page curl transitions. Live Text support with shake-to-toggle on iOS.
- **EPUB Reader** (iOS, macOS): Native engine with custom font importing (.ttf/.otf), theme presets, multi-column layouts, and nested TOC navigation.
- **Per-Book Preferences**: Save reading direction, page layout, and theme settings per book.
- **Incognito Mode**: Read without saving progress to server.

### Reader State and Settings Boundaries

- `ReaderSettingsSheet` is reserved for persisted reader preferences. Session-only reader options belong in the reader controls menu or the platform command menu.
- Page rotation is session-only, applies only to paged DIVINA modes, and must not be exposed or applied in Webtoon mode.
- `ReaderViewModel` owns the committed semantic reader position as a full `ReaderViewItem` plus its focused `ReaderPageID`. Page Curl adapters must not publish a position while mounting or dismantling; restoration may fall back to the first item, but explicit command resolution must be strict and discard invalid targets.
- `navigationTarget` is reserved for explicit navigation commands. Presentation rebuilds restore from the committed position and adapter-owned snapshots; they must not synthesize navigation commands, and a later interactive commit supersedes any earlier restoration anchor.
- Page Curl indices are local to one coordinator-owned immutable snapshot. UIKit controllers and asynchronous completions must cross update, preload, rotation, and teardown boundaries using stable reader-item identities rather than array indices or view tags.
- Scroll reader engine (`ScrollReaderEngine`) restoration resolves anchors strictly by page identity across item-list rebuilds, including pages that became the second half of a `.dual` pair after an orientation-driven layout flip. The pending initial position is carried as a full `ReaderPositionAnchor` (never a bare `ReaderViewItem`), so the focused page and remembered split side travel across rebuilds; resolution order is exact item match → remembered split side → focused page → `item.pageID`. Unresolvable anchors must be discarded (return `nil`), never substituted with a positional fallback: display-ordered snapshots are reversed for RTL, so a positional fallback can land on another segment's `.end` transition and skip the reader into the next book.
- Cover reader adapters (`NativeCoverPageView`) must never finalize a page-turn transition across an item-list rebuild boundary: `commitTransition` fails closed when the current/target item no longer resolves (discard and re-sync from the committed position), `teardown()` invalidates in-flight transition tokens, and a viewport size change cancels an in-flight user drag instead of letting rotation-distorted translations commit. A stale forward target at the last page is the segment's `.end` item and still matches by identity, so completing such transitions skips the reader to the volume transition card.
- During seamless DIVINA cross-book navigation, the committed `ReaderPositionAnchor` is the source of truth. `currentReaderPage` is its focused or backing page projection; `.end` items retain their segment's final `ReaderPageID` so book identity remains available. `currentBook` and `ReaderSession.book` follow that segment, while `currentBookId` remains the explicit whole-book load anchor.
- Split wide pages keep their committed side across layout rebuilds: `ReaderViewModel` remembers the last committed `.first`/`.second` side for the current page, a merge into `.both` (e.g. rotation to dual layout) preserves that memory instead of overwriting it, and position resolution prefers the remembered side before the first-item-per-page index. `ReaderPositionAnchor.preferredSplitPart` transports the side through adapter-owned snapshots (page curl) and rebuild anchors, and adapters must propagate it (via `ReaderViewItem.preferredSplitPart(preserving:)`) whenever they construct a new anchor, so rotating back from a merged spread returns to the same split half rather than the first half.

### Offline & Downloads

- **Background Downloads**: URLSession-based downloads with Live Activities on iOS.
- **Series Policies**: Manual, unread-only, or all books per series/read list.
- **Offline Mode**: Full reader functionality with downloaded content. Progress syncs when reconnected.
- **Two-Tier Caching**: Pages and thumbnails with adjustable limits and auto-cleanup.
- **Download Directory Lifecycle**: Cancelling a download removes its on-disk book directory. Failed downloads keep partial content for resume on retry, but empty directories left by early failures are removed immediately instead of becoming orphans.

### Browse & Dashboards

- **Dynamic Dashboards**: Keep Reading, On Deck, Recently Added, Recently Updated with real-time SSE updates.
- **Dashboard Book Card Style**: The Keep Reading section renders books as horizontal cards (`BookHorizontalCardView`: cover left, series/title/progress right) by default; classic cover cards remain available via the `dashboardHorizontalBookCards` toggle in Dashboard settings. Pinned read list/collection cards (`ReadListHorizontalCardView`, `CollectionHorizontalCardView`) share the same sizing via `LayoutConfig.horizontalCardWidth` / `LayoutConfig.horizontalCoverWidth`, and all three horizontal card types take their text styles from `LayoutConfig.horizontalCard{Title,Secondary,Tertiary}TextStyle(for:)`, which steps fonts up one tier in cozy density only.
- **Advanced Filters**: Search with metadata filters (authors, genres, tags, publishers) using all/any logic.
- **Grid/List Layouts**: Multiple density options (compact, standard, comfortable).
- **Library Filtering**: Browse per-library or across all libraries.
- **Series Batch Read Status**: Series detail book lists support a selection mode (Select button in the Books header, iOS/macOS only, hidden while offline) for batch Mark Read/Unread, mirroring the read list selection mode. `ReadStatusSelectionToolbar` reuses `BookSelectionItemView` cells; Select All covers the whole series via GRDB `fetchAllSeriesBookIds`, not just the loaded page. Marking loops per-book `BookService.markAsRead/markAsUnread` calls (Komga has no batch endpoint), tolerates partial failures, then resyncs the series and posts `postSeriesBooksDidChange` + `postReadStatusChanged`.

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
- **Series continue-reading accessory**: Rendered by the system via `tabViewBottomAccessory(isEnabled:)` in `PhoneTabView` on iOS 26.1+ only, driven by the shared `ReadingActionBarContext` written from `SeriesDetailView`. The modifier must stay permanently attached with `isEnabled` toggling visibility; conditionally attaching it rebuilds the tab subtree and causes a refresh loop. `SeriesDetailView` clears the context via a `ViewLifecycleObserver` at `viewWillDisappear` time (pop transition start) rather than SwiftUI `onDisappear` (post-teardown), and re-syncs at `viewDidAppear` so a cancelled interactive pop restores the accessory. It intentionally does not exist on iOS < 26.1, iPad, macOS, or tvOS (see convention 21); do not reintroduce a hand-written bar for those platforms.
- **Server page placement**: iPhone has no Server tab. The current-server card (`SettingsServerCardView`) plus single-row Management (`SettingsManagementView`) and Account (`SettingsAccountView`) entries live in `SettingsView` on iPhone only; iPad (sidebar) and tvOS keep the full `ServerView` page.
- **Reading Stats entry**: Reading stats are computed purely from local GRDB data, so the entry is not part of Server/Settings pages. It lives on the Dashboard: a toolbar button on iOS/macOS and a header button on tvOS, all pushing `NavDestination.settingsReadingStats`.
- **Settings page organization**: Top-level groups are Reader / Display / Server (iPhone only) / Behavior / Advanced / About (mirrored in the macOS Settings sidebar). Behavior holds user-facing feature toggles (SSE, Sync & Handoff, Spotlight); Advanced holds power-user/diagnostic pages (Network, Cache, Logs). Cross-reader toggles (e.g. Keep Screen Awake) live inline at the bottom of the Reader section, not in standalone one-item pages. About is its own page (`SettingsAboutView`), not an inline section. Section entry rows use `SettingsBadgeRow`/`SettingsSectionRow` with a colored icon badge (29×29 rounded square + white SF Symbol); new settings pages must register a `SettingsSection` case with icon and color instead of hand-rolling entry rows.

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
make clean              # Remove archives and exports
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

Version execution rules:
- Do not edit `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` manually in `KMReader.xcodeproj/project.pbxproj`; use `make bump`, `make minor`, or `make major`.
- `make minor` / `make major` increment `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` together and commit only the version file.
- Feature or fix PRs may include a generated `make bump` change when the change should produce a TestFlight or release-candidate build. This is the normal delivery flow and does not require a separate bump-only PR.
- It is expected that the aggregate PR diff shows both app-code files and `KMReader.xcodeproj/project.pbxproj` when the PR intentionally includes a build-number bump. Do not request removing the bump, creating a separate bump-only PR, or treating the PR as invalid solely because the PR-level diff includes both kinds of files.
- Release automation treats build upload and GitHub Release creation separately:
  - Any `CURRENT_PROJECT_VERSION` change uploads the current HEAD build to App Store Connect. For feature/fix PRs with an intentional `make bump` commit, this upload is expected: the resulting build may be used for TestFlight or as the release build.
  - A major transition such as `4.14 -> 5.0` uploads the `5.0` build but does not create a GitHub Release.
  - A same-major minor transition such as `5.0 -> 5.1` creates the GitHub Release for the previous marketing version (`v5.0`) at the previous commit, while the HEAD build can continue uploading as `5.1`.
  - GitHub Releases do not upload build artifacts.

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
./misc/translate.py update <key>  --zh-hans <zh-hans> --zh-hant <zh-hant> --de <de> --en <en> --es <es> --fr <fr> --it <it> --ja <ja> --ko <ko> --ru <ru>
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

- **UI**: SwiftUI, UIKit, and AppKit are all acceptable. Choose the most maintainable and platform-appropriate approach per feature.
- **State**: `@Observable` pattern (not `ObservableObject`)
- **Persistence**: GRDB for profiles/libraries/fonts/series/books/collections/read lists/dashboard caches, UserDefaults via `AppConfig`
- **Networking**: Centralized `APIClient` with feature-specific services
- **Real-time**: Server-Sent Events (SSE) via `SSEService`
- **Error Handling**: Route all user-visible errors through `ErrorManager.shared` (Core/Storage/Errors/)
- **Logging**: All logging goes through `AppLogger` with OSLog subsystems and categories

### Project Structure

```
KMReader/
├── MainApp.swift              # Entry point, GRDB setup, environment injection
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
│       ├── Cache/             # CacheManager, ImageCache, ThumbnailCache
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
│   │   ├── Services/          # SyncService, ProgressSyncService, SyncWorker
│   │   └── ViewModels/        # SyncViewModel
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

- `MainApp.swift`: Opens and migrates the GRDB store, configures stores, registers iOS AppDelegate for background downloads
- `ContentView.swift`: Chooses onboarding (`LandingView`) or authenticated shells
  - macOS and iPad: `MainSplitView`
  - iPhone: `PhoneTabView` (iOS 18+) or `OldTabView`
  - tvOS: `TVTabView` (tvOS 18+) or `OldTabView`
  - Shows `SplashView` during initialization (`SyncViewModel`)
- Reacts to `@AppStorage` flags (`isLoggedIn`, `enableSSE`, `isOffline`)
- Reader presentation: `ReaderOverlay` on iOS/tvOS, `ReaderWindowManager` + `ReaderWindowView` on macOS
- On startup: loads current user, sets offline mode, connects SSE if enabled
- On reconnect: syncs pending progress and resumes offline downloads
- On active scene: updates instance last-used and resumes offline syncs if online

**State & Persistence**

- **GRDB**: `KomgaInstance`, `KomgaLibrary`, `KomgaSeries`, `KomgaBook`, `KomgaCollection`, `KomgaReadList`, `CustomFont`, `PendingProgress` with dedicated stores
- **AppConfig**: Centralizes UserDefaults (server URL, tokens, SSE toggles, reader preferences, cache budgets, API timeout/retry settings)
- **Caches**: Multi-tier caching scoped per Komga instance via `CacheNamespace` (managed by `CacheManager`)
- Use `@AppStorage` in views, `AppConfig` elsewhere
- When building JSON strings for storage or cache keys, use `JSONSerialization` with `sortedKeys` to keep raw values stable and prevent redundant updates.

**Networking**

- `APIClient.swift`: Authenticated requests, JSON decoding, OSLog logging, configurable timeout and retry
- Feature services mirror `openapi.json` endpoints with pagination/filtering
- Services organized by domain: `AuthService`, `BookService`, `SeriesService`, `LibraryService`, etc.
- Authentication: `AuthService` + GRDB `KomgaInstance` stores + `AppConfig`

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

- `SyncService`: Syncs data between server and local GRDB storage
- `ProgressSyncService`: Syncs read progress to server
- `SyncViewModel`: Exposes synchronization state to SwiftUI and delegates work to `SyncWorker`
- `SyncWorker`: Runs synchronization, pagination, reconciliation, and persistence off the main actor

## Coding Conventions

1. **Comments**: Minimal, in English only
2. **Commit messages**: Concise, clear, semantic format, in English
3. **UI framework choice**: SwiftUI, UIKit, and AppKit may all be used. Pick the approach that best fits the feature, platform APIs, and maintainability.
4. **No inline Binding**: Avoid inline Binding usage
5. **No confirmationDialog**: Do not use confirmationDialog
6. **One type per file**: Every struct or class in a separate file
7. **@Observable over ObservableObject**: Use @Observable pattern for view models
8. **@AppStorage over UserDefaults**: In views use @AppStorage; elsewhere use AppConfig, UserDefaults is forbidden in files except AppConfig.swift
9. **Computed properties in view bodies**: Avoid stored variables in view bodies
10. **Settings descriptions**: Full settings pages may include explanatory description text, but in-reader settings sheets should keep controls compact and omit extra description text unless absolutely necessary.
11. **Platform differences**: Use `PlatformHelper` and `#if os(...)` blocks
12. **UI bridging discipline**: Interop between SwiftUI and UIKit/AppKit is allowed in either direction. Be explicit about dependency injection and verify environment/data propagation across hosting boundaries instead of assuming it will behave correctly.
13. **Object environment safety**: Do not use non-optional object-style environment dependencies (`@Environment(SomeType.self)`, `@EnvironmentObject`) in app code. Treat them as banned patterns. Pass object dependencies explicitly via initializers, context structs, or action closures. If environment lookup is still required, use a non-object custom `EnvironmentKey` or an optional lookup with controlled fallback/logging instead of crashing.
14. **No unchecked/unsafe APIs**: Do not use `@unchecked Sendable`, `nonisolated(unsafe)`, `unsafeBitCast`, or other `unsafe*` escape hatches in app code. Prefer safe ownership, actor boundaries, copying, or explicit wrappers. If a low-level API appears to require them, stop and redesign instead of introducing them.
15. **SwiftUI closure storage compatibility**: Do not store async, throwing async, actor-isolated, or `@Sendable` loader/transform closures directly in SwiftUI `View` value types. iOS 17 AttributeGraph can crash while visiting Swift 6 function metadata such as `nonisolated(nonsending)`. Prefer concrete source/command types, enums with methods, or explicitly passed model/service objects for this behavior. Ordinary synchronous UI callbacks are acceptable for simple event handlers, but avoid using closure fields as a general-purpose abstraction boundary in reusable views.
16. **SwiftUI animation boundaries**: Use local implicit `.animation(..., value:)` for micro-interactions such as button press styling, hover affordances, selected/checkmark states, and small status-chip transitions. Use explicit `withAnimation {}` for state transitions that change navigation, sheet/dialog presentation, page/section switching, list contents, pagination, loading/empty states, or other data-flow-driven UI updates. In complex views, prefer explicit animation at the mutation site so animation ownership is easy to audit; avoid broad/root `.animation(..., value:)` on containers that also render lists or multiple unrelated sections.
17. **Strongly avoid patch-style fixes for structural problems**: When the current abstraction or ownership boundary is wrong, do not preserve it by stacking flags, delays, version counters, bridge layers, or special cases just to keep the diff small. Prefer the larger refactor that moves the code toward the final stable architecture.
18. **Prioritize end-state quality over local diff size**: Stability, simplicity, clarity of ownership, and long-term maintainability are more important than minimizing code churn. Do not be afraid to rewrite or replace a local subsystem when that is the cleaner and more reliable design.
19. **If a temporary compatibility layer is unavoidable, mark it explicitly**: State why it exists, what the intended final design is, and what should be removed later. Temporary layers should be rare and treated as debt, not as the default implementation style.
20. **Keep boundary documentation current**: When a change introduces or changes a lifetime, ownership, persistence, navigation, platform, reader-mode, or UI-placement boundary, update `AGENTS.md` in the same change so the boundary remains explicit and enforceable.
21. **No compatibility shims for OS-gated features**: Unless a feature is explicitly required, do not hand-roll fallback implementations of newer system APIs for older OS versions. Gate the feature to the OS version that supports it natively and omit it on older systems, instead of building and maintaining a parallel custom implementation.

Additional patterns:

- Do not register or consume view models/coordinators through non-optional object-style SwiftUI environment dependencies
- Pass shared object dependencies explicitly at split/tab roots, `NavigationStack` roots, sheets, full-screen covers, scene boundaries, and any `UIHostingController`/`NSHostingController` boundary; do not assume outer environment inheritance is stable during snapshot, rotation, or scene transitions
- For architecture-level bugs, prefer replacing the confused layer instead of adding compensating state around it. Small patches are acceptable only when the underlying ownership model is already sound.
- SSE callbacks are single-assignment closures; implement dispatchers if multiple components need the same event
- Clearing caches/server data must go through `CacheManager` and GRDB stores
- New API endpoints belong in appropriate service; keep request-building out of views
- Dashboard/library selections stored via `LibraryManager` and related managers
- All logging goes through `AppLogger` with OSLog subsystems and categories
- Xcode project uses folder references (not groups); adding/removing files does not require editing `project.pbxproj`
- Do not use xcodebuild directly, use the Makefile instead.
- Translation all supported languages, refer to ../komga/komga-webui/src/locales/ if available.

### GRDB Migration Discipline

Runtime GRDB migrations in `LocalDatabase` are historical artifacts and must be treated as immutable once committed.

- Do not mutate already-registered GRDB migrations such as `create_runtime_schema_v1` or `00002_add_protected_server_flag` to add new columns, defaults, indexes, or table shape changes.
- Do not treat `create_runtime_schema_v1` helpers such as `createReadListTable` as current-schema builders. They define the frozen baseline for that migration.
- Any GRDB table shape change must be added as a new numbered migration after the latest registered migration. Fresh installs should reach the latest schema by running the baseline migration plus every later migration in order.
- When adding a new persisted field to a GRDB record, update the runtime record model and `CodingKeys`, then add a new migration that backfills a safe default for existing databases.
- Validate both upgrade and fresh install paths: an existing `KMReader.sqlite` must migrate forward, and a new empty database must run all migrations without duplicate-column or missing-column failures.

## Important Files

- `openapi.json`: Komga REST API contract
- `AGENTS.md`: Comprehensive contributor guide
- `Makefile`: Build automation commands
- `misc/`: Build scripts (`xcode.py`, `bump.sh`, `bump-version.sh`)

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
