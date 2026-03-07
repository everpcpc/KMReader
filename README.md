<div align="center">

# KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**Native SwiftUI Komga client for iOS, macOS, and tvOS.**

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://www.apple.com/tv/)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us)](https://apps.apple.com/app/id6755198424)

</div>

## Important Features

### Native Reading Experience

- DIVINA reader on iOS, macOS, and tvOS with LTR, RTL, vertical, Webtoon, spreads, zoom, customizable tap zones, page curl (iOS), and cover-style page transitions on all platforms.
- EPUB reader on iOS/macOS with paged, scrolled, and cover layouts, custom font importing (`.ttf`/`.otf`), theme presets, multi-column reading, and nested table of contents.
- Animated GIF and WebP pages start immediately, zoom naturally with the page, and stay stable across long reading sessions.
- PDF reading on iOS/macOS with a native PDF reader or DIVINA mode, plus search, table of contents, page jump, configurable render quality tiers for offline preparation, and clearer progress feedback.
- Per-book preferences save reading direction, page layout, and theme settings.
- Incognito mode and iOS Live Text support, including optional shake-to-toggle.

### Dashboard and Discovery

- Dashboard sections for Keep Reading, On Deck, Recently Added, Recently Updated, and pinned collections/read lists.
- Browse Series, Books, Collections, and Read Lists with metadata filters for publishers, authors, genres, tags, and languages using all/any logic.
- Save and reuse filters across browse surfaces.
- Optional unread-cover blur helps hide spoiler-heavy artwork until you start reading.
- Reading history and stats help surface recent activity from synced local data.
- Spotlight integration for downloaded content on iOS/macOS, plus iOS widgets and Home Screen quick actions for Keep Reading, Search, and Downloads.
- UI localization includes English, German, French, Japanese, Korean, Simplified Chinese, Traditional Chinese, Italian, Russian, and Spanish.

### Offline and Sync

- Download books for full offline reading across DIVINA, EPUB, and PDF workflows.
- EPUB downloads use a single-file download plus local extraction for faster, more reliable offline saves.
- Manual offline mode controls and resilient iOS background downloads for page files and extra resources.
- iOS Live Activities for both active reading sessions and downloads.
- Per-series download policies: Manual, Unread only, Unread + cleanup, and All books.
- Offline mode includes dedicated downloaded-library browsing and metadata filters.
- Progress and offline data sync automatically when reconnecting, including safer conflict handling.
- Cache controls cover pages and thumbnails.

### Multi-Server and Management

- Save multiple Komga servers and switch instantly.
- Sign in with username/password or API key, and manage Komga API keys inside the app.
- Admin tools for metadata editing, library management, media management (media analysis, missing posters, duplicate files and pages), task monitoring, and log viewing/export.

### Platform Highlights

- iOS/iPadOS: widgets, quick actions, Spotlight search, Dynamic Island Live Activities for reader/downloads, background downloads, Live Text, and page curl/cover transitions.
- macOS: dedicated reader windows, reader actions in the system menu bar, Spotlight search for downloaded content, keyboard shortcuts, and keyboard help overlay.
- tvOS: remote-first DIVINA reading with cover transitions and a TV-optimized browsing experience.

## Getting Started

### Prerequisites

- Komga 1.19.0+
- Xcode 15.0+
- iOS 17.0+, macOS 14.0+, tvOS 17.0+

### Build and run

```bash
git clone https://github.com/everpcpc/KMReader.git
cd KMReader
open KMReader.xcodeproj
```

```bash
make build-ios
make build-macos
make build-tvos

make run-ios-sim
make run-macos
make run-tvos-sim
```

## Compatibility

- Komga API v1 and v2

## Community

- [Discord](https://discord.gg/komga-678794935368941569)
