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

### Readers

- DIVINA reader on iOS, macOS, and tvOS with LTR, RTL, vertical, Webtoon, spreads, zoom, page curl on iOS, cover transitions, custom tap zones, keyboard support, and per-book preferences.
- EPUB reader on iOS/macOS with paged, scrolled, or cover layouts, custom fonts, themes, typography controls, status/footer overlays, multi-column reading, and nested table of contents.
- PDF reader on iOS/macOS with native PDF or DIVINA mode, search, table of contents, page jump, spread layouts, configurable render quality, and optional continuous scrolling.
- Animated GIF and WebP pages play inline. Incognito mode, page image actions, reader progress overlays, and iOS Live Text are supported where available.

### Browse and Discovery

- Dashboard sections for Keep Reading, On Deck, Recently Added, Recently Updated, and pinned collections/read lists.
- Browse Series, Books, Collections, and Read Lists with metadata filters, all/any matching, saved filters, reading history, and optional unread-cover blur.
- Spotlight indexing for downloaded content, plus iOS widgets and Home Screen quick actions for Keep Reading, Search, and Downloads.

### Offline and Sync

- Download books for offline reading across DIVINA, EPUB, and PDF workflows.
- Per-series policies support manual, unread-only, unread + cleanup, and all-books downloads.
- Large downloads stream to disk, and CBZ, CBR, PDF, and supported EPUB offline flows use local extraction or storage.
- Progress and offline changes sync when reconnecting. Cache controls cover pages and thumbnails.
- iOS background downloads and Live Activities show reader progress, incognito status, download progress, and processing state.

### Multi-Server and Management

- Save multiple Komga servers and switch instantly.
- Sign in with username/password or API key, and manage Komga API keys inside the app.
- Admin tools cover metadata editing, library management, media analysis, missing posters, duplicate files/pages, task monitoring, and log viewing/export.

### Platform Highlights

- iOS/iPadOS: widgets, quick actions, Spotlight search, Dynamic Island Live Activities, background downloads, Live Text, and reader keyboard shortcuts.
- macOS: dedicated reader windows, menu bar reader actions, Spotlight search, keyboard shortcuts, and keyboard help.
- tvOS: remote-first DIVINA reading and TV-optimized browsing.

KMReader UI is localized in English, German, French, Japanese, Korean, Simplified Chinese, Traditional Chinese, Italian, Russian, and Spanish.

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
