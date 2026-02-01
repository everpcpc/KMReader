<div align="center">

# 📚 KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**A full-featured native SwiftUI client for Komga — powerful readers, offline sync, library management, and admin tools.**

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://www.apple.com/tv/)
[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us)](https://apps.apple.com/app/id6755198424)

</div>

---

## ✨ Features

### Readers

- **DIVINA Reader** (iOS, macOS, tvOS): LTR/RTL/vertical/Webtoon modes with spreads, zoom, customizable tap zones, and page curl transitions. Live Text support with shake-to-toggle on iOS.
- **EPUB Reader** (iOS, macOS): Native engine with custom font importing (.ttf/.otf), theme presets, multi-column layouts, and nested TOC navigation.
- **Per-Book Preferences**: Save reading direction, page layout, and theme settings per book.
- **Incognito Mode**: Read without saving progress to server.

### Offline & Downloads

- **Background Downloads**: URLSession-based downloads with Live Activities on iOS.
- **Series Policies**: Manual, unread-only, unread+cleanup, or all books per series.
- **Offline Mode**: Full reader functionality with downloaded content. Progress syncs when reconnected.
- **Three-Tier Caching**: Pages, book files, and thumbnails with adjustable limits and auto-cleanup.

### Browse & Dashboards

- **Dynamic Dashboards**: Keep Reading, On Deck, Recently Added, Recently Updated with real-time SSE updates.
- **Advanced Filters**: Search with metadata filters (authors, genres, tags, publishers) using all/any logic.
- **Grid/List Layouts**: Multiple density options (compact, standard, comfortable).
- **Library Filtering**: Browse per-library or across all libraries.

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

---

## 🚀 Getting Started

### Prerequisites

- iOS 17.0+, macOS 14.0+, or tvOS 17.0+
- Xcode 15.0+
- Komga 1.19.0+ server

### Build & Run

```bash
git clone https://github.com/everpcpc/KMReader.git
cd KMReader
open KMReader.xcodeproj
```

Build commands:

```bash
make build-ios          # Build for iOS simulator
make build-macos        # Build for macOS
make build-tvos         # Build for tvOS simulator

make run-ios-sim        # Run on iOS simulator
make run-macos          # Run on macOS
make run-tvos-sim       # Run on tvOS simulator
```

See `Makefile` for all available commands.

---

## 🔌 Compatibility

- Requires **Komga 1.19.0** or later
- Works with **Komga API v1 and v2**
- SSE support for real-time updates
- EPUB and Webtoon readers available on iOS/macOS only

---

## 💬 Community

Join the discussion on [Discord](https://discord.gg/komga-678794935368941569).

---

<div align="center">

**Made with ❤️ for the Komga community**

⭐ Star this repo if you find it useful!

</div>
