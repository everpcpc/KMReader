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

- DIVINA reader on iOS, macOS, and tvOS with LTR, RTL, vertical, Webtoon, spreads, zoom, customizable tap zones, and page curl transitions.
- EPUB reader on iOS/macOS with paged, scrolled, and curl layouts, custom font importing (`.ttf`/`.otf`), theme presets, multi-column reading, and nested table of contents.
- PDF reading on iOS/macOS with a native PDF reader or DIVINA mode, plus search, table of contents, page jump, and offline preparation controls.
- Per-book preferences save reading direction, page layout, and theme settings.
- Incognito mode and iOS Live Text support, including optional shake-to-toggle.

### Dashboard and Discovery

- Dashboard sections for Keep Reading, On Deck, Recently Added, Recently Updated, and pinned collections/read lists.
- Browse Series, Books, Collections, and Read Lists with metadata filters for publishers, authors, genres, tags, and languages using all/any logic.
- Save and reuse filters across browse surfaces.
- Reading history and stats help surface recent activity from synced local data.
- Spotlight integration for downloaded content on iOS/macOS, plus iOS widgets and Home Screen quick actions for Keep Reading, Search, and Downloads.

### Offline and Sync

- Download books for full offline reading across DIVINA, EPUB, and PDF workflows.
- iOS background downloads with Live Activities.
- Per-series download policies: Manual, Unread only, Unread + cleanup, and All books.
- Offline mode includes dedicated downloaded-library browsing and metadata filters.
- Progress and offline data sync automatically when reconnecting.
- Cache controls cover pages, book files, and thumbnails.

### Multi-Server and Management

- Save multiple Komga servers and switch instantly.
- Sign in with username/password or API key, and manage Komga API keys inside the app.
- Admin tools for metadata editing, library management, task monitoring, and log viewing/export.

### Platform Highlights

- iOS/iPadOS: widgets, quick actions, Spotlight search, Live Activities, background downloads, Live Text, and page curl transitions.
- macOS: dedicated reader windows, Spotlight search for downloaded content, keyboard shortcuts, and keyboard help overlay.
- tvOS: remote-first DIVINA reading with a TV-optimized browsing experience.

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
