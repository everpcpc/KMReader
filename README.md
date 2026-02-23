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

### Reading Experience

- DIVINA reader on iOS/macOS/tvOS with LTR, RTL, vertical, spreads, zoom, and page curl transitions.
- Webtoon reading mode on iOS/macOS.
- EPUB reader on iOS/macOS with paged and scrolled flow, custom fonts (`.ttf`/`.otf`), and per-book preferences.
- PDF reading on iOS/macOS with native PDF mode, search, table of contents, and page jump.
- Per-book reading preferences and Incognito mode.

### Dashboard and Discovery

- Dashboard sections for Keep Reading, On Deck, recently added/updated content, and pinned sections.
- Pin collections and read lists to keep favorites at the top.
- Reading Stats page for daily, weekly, and monthly reading insights.
- Browse Series, Books, Collections, and Read Lists with metadata filters (publisher, author, genre, tag, language).

### Offline and Sync

- Download books for full offline reading.
- iOS background downloads with Live Activities.
- Per-series download policies: Manual, Unread only, Unread + cleanup, and All books.
- Offline mode supports metadata-based filtering to quickly find downloaded books.
- Progress and offline data sync automatically when reconnecting.

### Multi-Server and Management

- Save multiple Komga servers and switch instantly.
- Sign in with username/password or API key.
- Admin tools for metadata editing, library management, task management, and logs.

### Platform Highlights

- iOS/iPadOS: widgets, quick actions, background downloads, Live Activities.
- macOS: dedicated reader windows and keyboard-first controls.
- tvOS: remote-first DIVINA reading.

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
