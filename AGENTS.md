# AGENTS.md

General instructions for any coding agent working in this repository.

## Repository Snapshot
- **Project:** KMReader – native iOS, macOS, and tvOS Komga client supporting DIVINA (comic) and EPUB reading.
- **Platforms:** iOS 17+, macOS 14+, tvOS 17+ with platform-specific reader capabilities (Webtoon/iOS only, EPUB absent on tvOS).
- **Key dependencies:** Readium Swift Toolkit (EPUB), SDWebImage/SDWebImageSwiftUI, SwiftData, SwiftSoup, structured concurrency with async/await.
- **SwiftData schema:** `KomgaInstance`, `KomgaLibrary`, `CustomFont`.

## Build & Tooling
```bash
# Build default scheme
xcodebuild -project KMReader.xcodeproj -scheme KMReader build
# Platform-specific SDKs
xcodebuild -project KMReader.xcodeproj -scheme KMReader -sdk iphoneos build
xcodebuild -project KMReader.xcodeproj -scheme KMReader -sdk macosx build
xcodebuild -project KMReader.xcodeproj -scheme KMReader -sdk appletvos build
# Clean / open
xcodebuild -project KMReader.xcodeproj -scheme KMReader clean
open KMReader.xcodeproj
```
Default simulator in `.cursor` rules: iPhone 11 Pro Max.

## Architecture Core
- SwiftUI-first with the `@Observable` macro and `@MainActor` isolation; inject dependencies with `.environment()` instead of `.environmentObject()`.
- `APIClient.shared` centralizes HTTP interactions, injects tokens, and emits detailed logs through custom `APIError`.
- Authentication stack: `AuthViewModel`, `KomgaInstanceStore`, `AuthService`, and `AppConfig` values (`serverURL`, `authToken`) for active credentials.
- Service layer uses singletons (`BookService`, `SeriesService`, `CollectionService`, `ReadListService`, `LibraryService`, `LibraryManager`, `ManagementService`, `SSEService`).
- SSE opt-in (`AppConfig.enableSSE`, `AppConfig.showSSEStatusNotification`) keeps libraries/series/books in sync via `SSEService.shared`.

## Cache System
1. **Page Cache (`ImageCache` / `KomgaImageCache`)** – raw page images, `CacheSizeActor` for limits per instance.
2. **Book File Cache (`BookFileCache` / `KomgaBookFileCache`)** – EPUB downloads (5 GB default), async storage.
3. **Thumbnail Cache (`SDImageCacheProvider`)** – SDWebImage caches with WebP codec configuration.
All caches are namespaced by server instance via `CacheNamespace.directory(for:)` and cleared when an instance is removed.

## View & State Patterns
- ViewModels (`BookViewModel`, `SeriesViewModel`, `CollectionViewModel`, `ReadListViewModel`, `AuthViewModel`) handle async loading, pagination, and surface errors through `ErrorManager.shared`.
- Views folder structure: `Auth`, `Dashboard` (with `Sections`), `Browse`, `Series`, `Book`, `Collection`, `ReadList`, `Reader` (Divina/Epub/PageView), `History`, `Settings`, `Components`.
- `NavDestination` plus tab-based navigation; `@AppStorage` holds persistent preferences (theme, layout, cache limits). Avoid reading `AppConfig` directly in views.

## Reader Highlights
- **DivinaReaderView:** iOS/macOS/tvOS, LTR/RTL/Vertical/Webtoon (Webtoon only on iOS), zoom, tap zones, incognito, auto-hiding controls, preloading via `ImageCache`.
- **EpubReaderView:** iOS/macOS only with Readium, custom fonts (SwiftData `CustomFont`), offline EPUB via `BookFileCache`, ToC/themes/image-view mode.
- macOS adds dedicated reader window (`ReaderWindowView`) and Settings scene; tvOS provides DIVINA-only experience tuned for remote focus.

## Admin & Management
- Admin-only operations (library scans, metadata refresh, task queue, disk usage, metadata editing, analysis triggers) gated by `AppConfig.isAdmin` / `KomgaInstance.isAdmin`.
- `ManagementService` centralizes admin actions; `AdminRequiredView` guards UI.

## Error Handling & Logging
- `ErrorManager` exposes `alert(error:)` and `notify(message:)`, ensuring consistent user feedback (including clipboard copy support).
- `APIError` cases such as `.unauthorized`, `.forbidden`, `.badRequest`, `.serverError`, `.httpError`, `.networkError` always include URL context.
- Logging flows through `OSLog` (subsystem “KMReader”); API log format uses emoji markers (📡/✅/❌).

## Data & Filtering
- Models: `Book`, `Series`, `Collection`, `ReadList`, `Library`, `User`, `KomgaInstance`, `ReadProgress`, `BookPage`, `Page`.
- Browsing uses `BrowseContentType`, `BrowseLayoutMode`, and `BrowseLayoutHelper` to coordinate grid/list layouts with portrait/landscape nuances.
- Dedicated sort/filter enums (`SeriesSortField`, `BookSortField`, `ReadStatusFilter`, `SeriesStatusFilter`) conform to shared protocols for reuse.

## Common Code Patterns
```swift
// Pagination template
func loadItems(refresh: Bool = false) async {
    if refresh {
        currentPage = 0
        hasMorePages = true
        items = []
    }
    guard hasMorePages && !isLoading else { return }
    isLoading = true
    defer { isLoading = false }
    do {
        let page = try await service.getItems(page: currentPage, size: 20)
        withAnimation { items.append(contentsOf: page.content) }
        hasMorePages = !page.last
        currentPage += 1
    } catch {
        ErrorManager.shared.alert(error: error)
    }
}

// API usage
let result: MyModel = try await APIClient.shared.request(
    path: "/api/v1/resource",
    method: "GET",
    queryItems: [URLQueryItem(name: "page", value: "0")]
)
```
Cache helpers (`CacheManager.clearCache`, `ImageCache.getDiskCacheSize()`) and SwiftData `@Query` patterns follow SwiftData best practices.

## Coding Standards (from `.cursor/rules/default.mdc`)
1. Prefer SwiftUI; avoid UIKit/AppKit unless necessary.
2. No inline `Binding` usage; extract bindings for clarity.
3. Avoid `confirmationDialog` in SwiftUI.
4. Comments sparingly, always in English.
5. One struct/class per file.
6. Use `@Observable` rather than `ObservableObject`.
7. Avoid reading `AppConfig` directly inside views; use `@AppStorage`.
8. When persisting settings, go through `AppConfig` rather than raw `UserDefaults`.
9. Prefer computed properties instead of temporary variables declared inside view bodies.
10. Run and verify using the iOS Simulator (iPhone 11 Pro Max) or local macOS target when testing.

## Platform Reminders
- iOS: full feature set including Webtoon mode, EPUB reader, pinch-to-zoom, ability to export pages.
- macOS: separate reader window, keyboard shortcuts, Settings window, platform-adjusted controls/themes.
- tvOS: DIVINA reader only; limited to LTR/RTL/Vertical; focus-driven navigation optimized for remote input.

Always consider multi-server support: caches, credentials, and state must remain isolated per `KomgaInstance`. Use structured concurrency, scope operations to `@MainActor` where UI-affecting, and route all user-facing errors through `ErrorManager`.
