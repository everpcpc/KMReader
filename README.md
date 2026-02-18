<div align="center">

# KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**Full-featured native SwiftUI Komga client for iOS, macOS, and tvOS.**

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://www.apple.com/tv/)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us)](https://apps.apple.com/app/id6755198424)

</div>

## Important Features

### Readers

- DIVINA reader on iOS/macOS/tvOS with LTR/RTL/vertical/Webtoon modes, spreads, zoom, and tap zones.
- EPUB reader on iOS with custom font import (`.ttf`/`.otf`), theme presets, layout controls, and per-book EPUB preferences.
- Native PDF reader on iOS/macOS with TOC, page jump, search, and reading direction/layout controls.
- Incognito mode to read without sending progress updates.

### Offline & Sync

- Download books for full offline reading.
- iOS background download queue with Live Activities.
- Per-series offline policies: `Manual`, `Unread only`, `Unread + cleanup read`, `All`.
- Auto-resume downloads and pending progress sync when back online.

### Browse & Real-Time

- Dashboard sections: Keep Reading, On Deck, Recently Released/Added/Read books, Recently Added/Updated series.
- SSE-based dashboard auto refresh with debounce and reader-aware timing.
- Browse Series, Books, Collections, and Read Lists.
- Metadata filters (publisher, author, genre, tag, language) with all/any logic.

### Multi-Server & Account

- Save multiple Komga servers and switch instantly.
- Login with username/password or API key.
- Manage API keys and view authentication activity.

### Admin & Diagnostics

- Edit metadata for series, books, collections, and read lists.
- Create/edit/delete libraries with scanner options and directory browser.
- Monitor server task queues and cancel all tasks.
- Built-in logs viewer with filters and export.

### Platform Highlights

- iOS/iPadOS: widgets, quick actions, background downloads, Live Activities.
- macOS: dedicated reader window and keyboard-first workflows.
- tvOS: remote-first DIVINA reading experience.
- iOS/macOS: optional Spotlight indexing for downloaded books and series.

## Getting Started

### Prerequisites

- Komga 1.19.0+
- Xcode 15.0+
- iOS 17.0+, macOS 14.0+, or tvOS 17.0+

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
- SSE-based real-time updates

## Community

- [Discord](https://discord.gg/komga-678794935368941569)
