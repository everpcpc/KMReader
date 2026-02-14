<div align="center">

# KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**Full-featured native SwiftUI client for Komga on iOS, macOS, and tvOS.**

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://www.apple.com/tv/)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us)](https://apps.apple.com/app/id6755198424)

</div>

## Important Features

### Reader stack

- DIVINA reader on iOS, macOS, and tvOS with multiple reading directions, spread support, zoom, and tap-zone controls.
- EPUB reader on iOS with custom fonts (`.ttf`/`.otf`), theme presets, and per-book EPUB preferences.
- PDF reader on iOS and macOS with direction/layout controls, TOC, page jump, and search.
- Incognito reading mode that skips reading-progress sync.

### Offline and sync

- Download books for full offline reading.
- iOS background downloads with Live Activities.
- Per-series offline policies: `Manual`, `Unread only`, `Unread + cleanup read`, `All`.
- Automatic progress sync and queue resume when back online.

### Browse and discovery

- Dashboard sections: Keep Reading, On Deck, Recently Added, Recently Updated, Recently Released, Recently Read.
- Real-time dashboard refresh via server-sent events (SSE).
- Advanced metadata filters with all/any logic (authors, tags, genres, publishers, languages).
- Grid/list layouts and saved filters.

### Multi-server and account

- Multiple Komga server profiles with fast switching.
- Login with username/password or API key.
- API key management and authentication activity view.

### Admin and operations

- Metadata editing for series, books, collections, and read lists.
- Library management with scanner settings and directory browser.
- Task queue monitoring and cancel-all tasks.
- In-app logs viewer with filtering and export.

### Platform highlights

- iOS/iPadOS: background downloads, Live Activities, widgets.
- macOS: separate reader window flow and keyboard help overlay.
- tvOS: remote-first DIVINA reading experience.
- iOS/macOS: optional Spotlight indexing for downloaded content.

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
