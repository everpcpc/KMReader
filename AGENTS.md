# AGENTS.md

## Purpose
This file orients new contributors (human or AI) to the KMReader codebase so feature work, code review, and debugging can start quickly. It captures the architecture, critical flows, and tooling conventions that are scattered across SwiftUI views, SwiftData stores, services, and release scripts.

## Repo Snapshot
- **App**: Native SwiftUI client for Komga targeting iOS, macOS, and tvOS. Main entry point is `KMReader/MainApp.swift`, which injects `AuthViewModel` and `ReaderPresentationManager` into the environment and wires SwiftData containers for persisted entities.
- **Layers**: `Views/` contains feature-specific SwiftUI scenes, `ViewModels/` holds `@Observable` state objects, `Services/` wraps Komga APIs/cache/storage, and `Models/` defines DTOs, SwiftData models, and reader structs.
- **State**: `AppConfig` (UserDefaults-backed) stores credentials, preferences, and cache budgets; `SwiftData` stores server profiles (`KomgaInstance`), libraries, and custom fonts; caches in `Services/Cache` keep thumbnails, page images, and EPUB files per Komga instance.
- **Networking**: `Services/Core/APIClient.swift` centralizes HTTP access, headers, logging, and decoding. Feature services (Auth, Library, Series, Book, Collection, ReadList, Management) wrap specific endpoints that mirror `openapi.json`.
- **Real-time**: `Services/SSE/SSEService.swift` manages server-sent events, reconnect logic, and dispatches events back into view models (dashboard, series, books, thumbnails, task queues).

## Architecture Overview
### App lifecycle & navigation
- `MainApp.swift` loads SwiftData schema (`KomgaInstance`, `KomgaLibrary`, `CustomFont`), configures stores (`KomgaInstanceStore`, `KomgaLibraryStore`, `CustomFontStore`), and sets up SDWebImage coders. It declares `WindowGroup`s for the main shell and, on macOS, a dedicated `reader` window and settings scene.
- `ContentView.swift` decides between onboarding (`LandingView`) and the authenticated tab experience (`MainTabView` for iOS 18+/macOS 15+/tvOS 18+, `OldTabView` otherwise). It reacts to `@AppStorage` flags (`isLoggedIn`, `enableSSE`, `themeColorHex`) to load user data, connect/disconnect SSE, update caches, and show a global `ErrorManager` overlay. On iOS/tvOS it drives the reader via `.fullScreenCover`; on macOS it delegates to `ReaderWindowManager`.

### State & persistence
- **SwiftData**: `Models/Auth/KomgaInstance.swift`, `Models/Library/KomgaLibrary.swift`, and `Models/Reader/CustomFont.swift` define local records. Stores in `Services/Auth/KomgaInstanceStore.swift`, `Services/Library/KomgaLibraryStore.swift`, and `Services/Reader/CustomFontStore.swift` encapsulate fetch/upsert/delete logic and migrations.
- **User defaults**: `Services/Core/AppConfig.swift` centralizes everything stored in `UserDefaults` (server URL, tokens, SSE toggles, reader preferences, dashboard layout, cache budgets). `@AppStorage` mirrors these keys inside SwiftUI views (`SettingsSSEView`, `SettingsCacheView`, `SettingsServersView`, `DashboardView`, etc.).
- **Caches**: `Services/Cache/ImageCache.swift`, `BookFileCache.swift`, and `SDImageCacheProvider.swift` implement multi-tier caching for pages, book files, and thumbnails. `CacheNamespace.swift` scopes disk paths per Komga instance; `CacheManager.clearCaches(instanceId:)` is called when removing a server. UI controls live in `Views/Settings/SettingsCacheView.swift`.
- **Library/session helpers**: `LibraryManager` keeps a minimal list of libraries per instance in SwiftData, while `ReaderPresentationManager` stores the currently presented book/read list, handles macOS window lifecycle, and exposes `closeReader()` for the UI.

### Networking & API layer
- `Services/Core/APIClient.swift` builds authenticated requests (including a custom user-agent), decodes JSON, logs failures via `OSLog`, and exposes helpers (`request`, `requestTemporary`, `requestData`, `requestOptional`). Errors are normalized through `Services/Core/Errors`.
- Feature services (e.g., `Services/Auth/AuthService.swift`, `Services/Book/BookService.swift`, `Services/Series/SeriesService.swift`, `Services/Collection/CollectionService.swift`, `Services/ReadList/ReadListService.swift`, `Services/Library/LibraryService.swift`, `Services/Core/ManagementService.swift`) encapsulate Komga endpoints, sorting/filtering, and pagination. `openapi.json` mirrors Komga’s contract if you need payload reference.
- Authentication flows (`AuthViewModel.swift`, `LoginView.swift`, `SettingsServersView.swift`) rely on `AuthService` plus `KomgaInstanceStore` to persist credentials and `AppConfig` to flip `isLoggedIn`, `currentInstanceId`, and SSE toggles.

### Real-time updates
- `SSEService` connects to `/sse/v1/events` once per session, exposes per-entity callbacks (libraries, series, books, read lists, thumbnails, queues, sessions), and honors `AppConfig.enableSSE`, notifications, and auto-refresh toggles.
- `ContentView` and `SettingsSSEView` own connection state. View models such as `BookViewModel.swift` and `SeriesViewModel.swift` register closures to refresh current items when events arrive. `Views/Dashboard/DashboardView.swift` debounces events and updates its `DashboardConfiguration` stats, pausing while the reader is open.

### UI & feature surfaces
- **Dashboard/Browse/Admin**: `Views/Dashboard` renders configurable sections (Keep Reading, On Deck, Recently Added/Read/Released/Updated) and uses `DashboardBooksSection`/`DashboardSeriesSection` to load data via shared view models. Library filters live in `DashboardConfiguration` (AppStorage).
- **Browse/Detail**: Feature directories under `Views/Book`, `Views/Series`, `Views/Collection`, and `Views/ReadList` share the browse infrastructure defined in `ViewModels/Common/BrowseOptions.swift` & friends, plus SSE-backed updates and action sheets for mark read/unread, edit metadata, etc.
- **Settings**: `Views/Settings` contains modular forms for servers, appearance, caches, SSE, downloads, and (on macOS) a dedicated settings window (`SettingsView_macOS`). `SettingsServersView` relies on `@Query` to list SwiftData instances and handles login/logout, edit, and delete scenarios.
- **Readers**: `Views/Reader` hosts the DIVINA/comic/EPUB/Webtoon reader implementations, overlay controls, tap zones, keyboard shortcuts, and macOS window adapters. `ReaderViewModel.swift`, `ReaderManifestService.swift`, and `ReaderMediaHelper.swift` manage manifest resolution, caching, and download deduplication. `ReaderPresentationManager.swift` coordinates transitions, incognito mode, and `ReaderWindowManager` on macOS.
- **Auth/onboarding**: `Views/Auth/LoginView.swift` is the primary entry, wrapped by `SettingsServersView` when onboarding new servers. It uses `@AppStorage` to pre-fill previous URLs/usernames and reports errors via `AuthViewModel`.
- **Error & notification UX**: `Services/Core/Errors/ErrorManager.swift` exposes `alert` and `notify`. `ContentView` listens for `hasAlert` to show modals, while non-blocking notifications stack in a bottom overlay.

### Admin & maintenance flows
- `Services/Core/ManagementService.swift` exposes actuator and task queue APIs, gated behind `AppConfig.isAdmin`.
- `SettingsSSEView`, `SettingsCacheView`, and `SettingsDownloadsView` let users tune real-time updates, cache budget, and download behavior, calling into `SSEService`, `ImageCache`, and `BookFileCache`.
- Removing a server through `SettingsServersView` deletes its SwiftData rows, empty caches via `CacheManager.clearCaches(instanceId:)`, and severs SSE connections.

## Directory Tour
- `KMReader/MainApp.swift`, `KMReader/ContentView.swift`: Application entry, dependency injection, and scene selection.
- `KMReader/Views/`: SwiftUI views grouped by feature (`Auth`, `Dashboard`, `Book`, `Series`, `ReadList`, `Settings`, `Reader`, etc.). macOS-only views sit beside cross-platform variants (e.g., `SettingsView_macOS.swift`, `ReaderWindowView.swift`).
- `KMReader/ViewModels/`: `@Observable` state objects for each feature plus shared browse option structs. They rely on the corresponding services and dispatch UI-side `ErrorManager` messages.
- `KMReader/Services/`: API clients (`Core`), domain services (Auth/Book/Series/Collection/ReadList/Library), caches (`Cache`), reader font store, and SSE plumbing. Each service is a singleton to keep networking consistent.
- `KMReader/Models/`: Data transfer objects, SwiftData models, SSE payloads, reader helper structs, and dashboard configuration types.
- `KMReader/Common/`: Cross-cutting helpers for filenames, languages, and platform abstractions (`PlatformHelper`).
- `KMReader/Resources/` & `Assets.xcassets`: Bundled JS/css/assets for the readers and iconography.
- Repository root extras: `Makefile` (build/archive/bump commands), `misc/` automation scripts (`archive.sh`, `release.sh`, `bump-version.sh`, etc.), `openapi.json` for API reference, `APP_STORE_DESCRIPTION.txt`, marketing `static/` site assets, and `icon.svg`.

## Build, Tooling & Release
- Requires Xcode 15+, Swift 5.9+, and the `KMReader.xcodeproj`. Launch via `open KMReader.xcodeproj` or Xcode UI.
- Use the `Makefile` for consistent automation:
  - `make build-ios`, `make build-macos`, `make build-tvos` compile per platform (device SDKs).
  - `make build-ios-ci`, `make build-macos-ci`, `make build-tvos-ci` target simulators with code signing disabled (CI-friendly smoke tests).
  - `make archive-*` and `make export` wrap the scripts in `misc/` to produce `.xcarchive`/export artifacts; `make release` orchestrates multi-platform archives/exports and `make artifacts` prepares App Store-ready IPA/DMG bundles.
  - Version bumps are scripted via `make bump`, `make major`, `make minor`, which call into `misc/bump*.sh`.
- Marketing/website collateral sits under `static/`. Update `APP_STORE_DESCRIPTION.txt` when App Store copy changes to keep automation working.

## Working Notes for Agents
- Cursor rules in `.cursor/rules/default.mdc` apply globally: keep comments minimal and in English, favor SwiftUI over UIKit/AppKit, avoid inline `Binding` usage, `confirmationDialog`, and `ObservableObject` (use `@Observable`). Every type belongs in its own file. Access UserDefaults keys via `@AppStorage` in views and `AppConfig` elsewhere. Prefer computed properties instead of stored variables inside view bodies, and run tests with the iOS Simulator (iPhone 11 Pro Max) or macOS where possible.
- Adopt `@MainActor` + `@Observable` for any new stateful type that touches the UI, mirroring `AuthViewModel`, `BookViewModel`, etc. Inject them through the SwiftUI environment instead of singletons when possible (`MainApp` is the canonical registration point).
- Always route user-visible errors through `ErrorManager.shared`, and prefer `ErrorManager.notify` for transient success to keep ContentView’s overlay consistent.
- When touching authentication or server switching, update `AppConfig` fields **after** validating credentials (`AuthViewModel.applyLoginConfiguration`) and remember to refresh libraries plus reconnect SSE.
- SSE callbacks are single-assignment closures on `SSEService`. If multiple components need the same event, implement a dispatcher inside the subscribing view model or convert to NotificationCenter-style fan-out instead of reassigning elsewhere.
- Clearing caches/server data must go through `CacheManager` and the SwiftData stores to avoid orphaned disk state. `SettingsServersView.delete` demonstrates the full teardown path.
- Reader-specific work should reuse `ReaderViewModel`, `ReaderManifestService`, and the caching helpers; keep incognito and `readList` handoffs inside `ReaderPresentationManager` so macOS/iOS/tvOS stay in sync.
- Platform differences live in `PlatformHelper`. Use it (and existing `#if os(...)` blocks in views) when adding behaviors that differ between iOS, macOS, and tvOS (keyboard shortcuts, tap zones, sheet styles, etc.).
- New API endpoints belong in the appropriate service alongside pagination/sort helpers. Keep request-building logic (query items, payload structs) out of views.
- Dashboard/library selections are stored via `DashboardConfiguration` and `LibraryManager`; reuse those helpers so selections persist per Komga instance.

## Testing & Validation
- There are no XCTest targets in this repo. Validating changes generally means:
  - Building every target relevant to your change (`make build-ios` / `make build-macos` / `make build-tvos` or CI variants).
  - Exercising flows manually: login/logout, server switching, dashboard refresh, SSE auto-refresh, reader opening/closing, cache clearing.
  - Watching the Xcode Console filtered by subsystem `Komga` with categories like `API`, `SSE`, or `ReaderViewModel` for log diagnostics.
- Add ad-hoc diagnostics (e.g., `Logger`) rather than print statements and remove them or downgrade to `logger.debug` before submitting patches.

## Reference Assets
- **API schema**: `openapi.json` mirrors Komga’s REST contract; consult it when adding new DTOs or filters.
- **Store copy & marketing**: `APP_STORE_DESCRIPTION.txt`, `static/`, and `buildServer.json` hold metadata used by release automation.
- **Iconography**: `icon.svg` (plus `Assets.xcassets`) defines the app icon used across platforms.
- **Legal**: `LICENSE` (MIT) governs contribution expectations.
