# AGENTS.md

Rules that must not be violated when working in this repository. For architecture and feature details, read the code.

## Project

**KMReader** is a native SwiftUI client for [Komga](https://github.com/gotson/komga). iOS 17+ / macOS 14+ / tvOS 17+, Swift 6, Xcode 15+. There are no XCTest targets: validate with builds and manual testing.

## Commands

All builds run through the Makefile (wrapping `misc/xcode.py`); never invoke `xcodebuild` directly.

```bash
make build          # build all platforms (preferred validation)
make build-ios      # platform-specific; run sequentially, never in parallel
make build-macos    #   (xcodebuild shares one DerivedData database)
make build-tvos
make run-ios-sim / make run-macos / make run-tvos-sim   # run (device choice persisted in devices.json)
make format         # format code after editing
make localize       # update localizations; ./misc/translate.py list|update for keys
make bump / make minor / make major   # version management
```

Never edit `MARKETING_VERSION` or `CURRENT_PROJECT_VERSION` in `project.pbxproj` by hand. A `make bump` commit in a feature/fix PR is the normal delivery flow, not a separate PR.

After changing code: `make format`, then `make build`. Simulator interaction and debugging go through `baguette` (see the `baguette` skill): filter logs with subsystem `com.everpcpc.kmreader` (categories `API`, `SSE`, `ReaderViewModel`).

## Reader State Boundaries

- `ReaderSettingsSheet` is for persisted preferences only. Session-only options (e.g. page rotation) belong in the reader controls menu / platform command menu. Rotation is session-only, paged DIVINA modes only, never Webtoon.
- `ReaderViewModel` owns the committed semantic position as a full `ReaderViewItem` plus its focused `ReaderPageID`. Page Curl adapters must not publish a position while mounting or dismantling.
- `navigationTarget` is reserved for explicit navigation commands; rebuilds restore from the committed position and adapter snapshots, never synthesize commands, and a later interactive commit supersedes any restoration anchor. When a command already resolves to the current position, clear `navigationTarget` synchronously before committing (committing first loops).
- Page Curl indices are local to one coordinator-owned immutable snapshot; cross update/preload/rotation/teardown boundaries by stable reader-item identity, never array indices or view tags. Programmatic turns keep their `setViewControllers` completion authoritative; `willTransitionTo` must not invalidate the in-flight transition token. Programmatic `setViewControllers` must never land while a pan gesture is active (`willTransitionTo` only fires once a curl starts); coordinators gate on the pan recognizers' live state and stash work until the pan ends, like `isTransitioning`.
- `ScrollReaderEngine` restores anchors strictly by page identity across item-list rebuilds, carrying the pending position as a full `ReaderPositionAnchor` (never a bare `ReaderViewItem`). Unresolvable anchors are discarded (`nil`), never positionally substituted.
- Cover adapters (`NativeCoverPageView`) never finalize a page-turn transition across an item-list rebuild; `teardown()` invalidates in-flight tokens, and a viewport size change cancels an in-flight drag.
- Seamless cross-book navigation: the committed `ReaderPositionAnchor` is the source of truth; `.end` items retain their segment's final `ReaderPageID`; `currentBook`/`ReaderSession.book` follow the segment; `currentBookId` remains the whole-book load anchor.
- In offline-first reading, `ReaderViewModel.nextBookOfflineState` is the single observable for the next book's offline readiness, rendered by end-page/footer UIs. The status row is a permanently reserved constant-height slot toggled by alpha — never `isHidden`, which would re-lay out the page; in streaming mode the slot collapses entirely. Adapters refresh end content only via the page-presentation invalidation channel. The next-segment preload trigger distance must stay ahead of the download, not just the page turn.
- Split wide pages keep their committed side across layout rebuilds; propagate it via `ReaderPositionAnchor.preferredSplitPart` and `ReaderViewItem.preferredSplitPart(preserving:)` whenever adapters construct a new anchor.

## Sync, Offline & Caching

- Any path that pulls reading progress after coming online must first `await ProgressSyncService.syncPendingProgress` (it waits for an in-flight push), so a pull never overwrites newer offline-queued local progress.
- Cancelling a download removes its on-disk book directory; failed downloads keep partial content for resume.
- Clearing caches or server data goes through `CacheManager` and the GRDB stores only.

## Browse & Dashboard

- Browse pages paginate with `PaginationState(pageSize: 50)`. Notification-driven refreshes revalidate the loaded window in place via `PaginationState.replaceItems`; full `pagination.reset()` is reserved for initial loads and explicit user actions.
- User-facing metadata lists (authors, publishers, genres, tags, languages) sort with `Collection.localizedSorted()`; authors via `Author.sortedByRole()`. Never revert to raw `.sorted()`. (`MetadataIndex` encode keys and SQL clause ordering intentionally keep plain `.sorted()`.)
- Online ordering is server-side; the app-local pinned flag is invisible to the server, so online pages prepend pinned items and filter them out of the server stream.
- Dashboard progress sections always revalidate on `.readingProgress`; other sections skip unless browse options are progress-sensitive (`isSensitiveToReadingProgress`).
- `.refreshable` closures must await the reload they trigger, so the refresh control dismisses onto settled content instead of racing in-flight view updates. Dashboard manual refreshes suspend in `DashboardRefreshCoordinator` until every rendered section acknowledges the command (section views register on appear/disappear); `OfflineView` awaits the browse view models it owns and shares with `OfflineSeriesBrowseView`/`OfflineBooksBrowseView`, whose `refreshBrowse()` re-runs the view model's current query; library-selection and account-switch reloads instead bump a `refreshTrigger` passed to those child views, so the reload runs through the child and captures the current `libraryIds` rather than replaying the view model's stale query.

## Detail Pages

- Detail pages follow a fixed hierarchy: hero (cover beside title, author chips, and quiet `DetailMetadataRow` facts), a `DetailActionCard` grouping reading state with primary actions (the page's single focal point; the series continue-reading button and `SeriesDownloadActionsSection` are injected by `SeriesDetailView` through the content view's `actions` slot), summary, `DetailChipFlowSection` chips for relational metadata (genres/tags/publisher/external links), headline sections (alternate titles, media information), and `DetailTimestampsView` as the quiet footer. Chips follow the Komga web UI's tag style (`DetailChip`): small outlined rounded-rect, neutral, no per-field colors or filled backgrounds; icons only where they carry meaning (author role, external link). State color appears only as text: green/orange/red and `MediaStatus.detailColor`/series `statusColor` in the action card; static metadata stays secondary.

## Platform UI Placement

- Series continue-reading accessory: `tabViewBottomAccessory(isEnabled:)` in `PhoneTabView` (iOS 26.1+ only), modifier permanently attached with `isEnabled` toggling visibility; other platforms use the inline `SeriesReadingActionButton`. Do not reintroduce the floating `safeAreaInset` bar.
- iPhone has no Server tab: the current-server card plus Management/Account entries live in `SettingsView` on iPhone only; iPad/tvOS keep the full `ServerView`.
- iPhone Library tab root is `LibraryBrowseView`; its scope is the global dashboard selection (no tab-local store). `LibraryScopeToolbarButton` is the shared leading button (explicit `HStack` icon + `Text`, sheet/list owned by the parent view), always shown at tab roots regardless of library count; a single library is titled with its name.
- `NavDestination.browseLibrary` carries its `LibrarySelection` in the destination value; do not reintroduce side channels into `BrowseView`.
- Reading stats entry lives on the Dashboard (toolbar menu item on iOS/macOS, header button on tvOS), pushing `NavDestination.settingsReadingStats`.
- Detail page heroes (Series/Book/OneShot) share `DetailHeroView`: compact widths stack a large centered cover above the centered info block, regular widths keep the side-by-side row at `PlatformHelper.detailThumbnailWidth`. Hero subviews adapt alignment through the `detailHeroCentered` environment value, injected by `DetailHeroView` itself — never read `horizontalSizeClass` inside shared hero subviews. All chip rows (hero creator row, genres, tags, links) go through the single data-driven `DetailChipFlow` component; do not add per-field chip containers.
- Toolbar trailing policy: at most one trailing toolbar button per content page (two only when a primary action sits next to the single ellipsis menu, e.g. Dashboard search). Everything else lives inside the ellipsis menu; sheet/alert presentations from menu items must go through `deferMenuActionPresentation`.
- Settings pages: top-level groups are Reader / Display / Server (iPhone only) / Behavior / Advanced / About. OS-level toggles belong in `SettingsSystemFeaturesView`; new pages register a `SettingsSection` case and use `SettingsBadgeRow`/`SettingsSectionRow` entries.

## Coding Conventions

1. **Comments**: minimal, English only.
2. **Git-facing text**: commit messages, PR titles/bodies, and review comments are always in English.
3. **UI frameworks**: SwiftUI, UIKit, and AppKit are all acceptable; pick per feature and platform.
4. **No inline `Binding`**.
5. **No `confirmationDialog`**.
6. **One type per file**.
7. **State**: `@Observable`, never `ObservableObject`.
8. **Preferences**: `@AppStorage` in views, `AppConfig` elsewhere; `UserDefaults` only inside `AppConfig.swift`.
9. No stored variables in view bodies; avoid computed-property clutter there too.
10. In-reader settings sheets stay compact; full settings pages may carry description text.
11. Platform differences via `PlatformHelper` and `#if os(...)`.
12. UIKit/AppKit interop in either direction is fine; be explicit about dependency injection and verify environment/data propagation across hosting boundaries.
13. **Banned**: non-optional object-style environment dependencies (`@Environment(SomeType.self)`, `@EnvironmentObject`). Pass objects via initializers, context structs, or action closures; use non-object custom `EnvironmentKey`s when needed.
14. **Banned**: `@unchecked Sendable`, `nonisolated(unsafe)`, `unsafeBitCast`, other `unsafe*` escape hatches. Redesign instead.
15. Do not store async/throwing/`@Sendable` closures in SwiftUI `View` value types (iOS 17 AttributeGraph crash risk); use concrete command types or passed-in services.
16. **Animation boundaries**: local implicit `.animation(..., value:)` only for micro-interactions (press/hover/selected states); explicit `withAnimation {}` for navigation, presentation, content, and pagination changes. No broad/root `.animation` on containers rendering lists.
17. No patch-style fixes for structural problems; no compensating flags/delays/counters around a broken ownership boundary. Refactor toward the stable architecture.
18. End-state quality beats diff size; do not fear rewriting a subsystem when that is the cleaner design.
19. Temporary compatibility layers must say why they exist and what replaces them; treat them as debt.
20. When a change alters a lifetime, ownership, persistence, navigation, platform, reader-mode, or UI-placement boundary, update `AGENTS.md` in the same change.
21. No hand-rolled fallback shims for newer OS APIs; gate features to the OS version that supports them natively.
22. **No force casts** (`as!`), especially on GRDB `Row` subscripts; use the generic converting subscript (`let date: Date = row["created_date"]`) or `as?` with a fallback.
23. Never render an empty `HStack`/`VStack`; put the condition around the stack itself so nothing renders when there is no content.

Additional patterns:

- Pass shared object dependencies explicitly at split/tab roots, `NavigationStack` roots, sheets, full-screen covers, scene boundaries, and any `UIHostingController`/`NSHostingController` boundary; do not assume environment inheritance survives snapshot/rotation/scene transitions.
- SSE callbacks are single-assignment closures; implement dispatchers when multiple components need the same event.
- New API endpoints belong in the appropriate service; keep request-building out of views.
- Dashboard/library selections persist via `LibraryManager` and related managers.
- All logging goes through `AppLogger` (OSLog subsystems/categories); user-visible errors through `ErrorManager.shared` (`notify` for transient success).
- The Xcode project uses folder references (not groups); adding/removing files does not require editing `project.pbxproj`.
- Translate all supported languages (see `misc/translate.py`); reference `../komga/komga-webui/src/locales/` when available.
- When building JSON strings for storage or cache keys, use `JSONSerialization` with `sortedKeys` for stable raw values.

## GRDB Migration Discipline

Runtime GRDB migrations in `LocalDatabase` are immutable once committed.

- Never mutate an already-registered migration (e.g. `create_runtime_schema_v1`, `00002_add_protected_server_flag`) or its helpers; they are the frozen baseline.
- Any table shape change is a new numbered migration after the latest one; fresh installs run baseline + all later migrations in order.
- New persisted field: update the record model and `CodingKeys`, then add a migration backfilling a safe default.
- Validate both upgrade and fresh-install paths.
