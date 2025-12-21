<div align="center">

# 📚 KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**Native iOS, macOS, and tvOS client for [Komga](https://github.com/gotson/komga) with comic and EPUB readers**

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://www.apple.com/tv/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us)](https://apps.apple.com/app/id6755198424)

</div>

---

## ✨ Highlights

- **Multi-server vault**: Save unlimited Komga servers with custom names and role-aware access. Supports both password and API key authentication. Per-profile cache clearing and credential storage stay on-device.
- **Cloud-drive-like offline**: Series and books support offline policies (manual, latest, all) with automatic downloads and smart sync. Automatic offline mode switching detects network errors and notifies you. Read progress made offline queues locally and syncs when connection restores. Browse dashboards, libraries, series, and collections seamlessly with cached data—switch between online and offline reading without interruption.
- **Browse + dashboards**: Series, books, collections, and read lists share search, filters, infinite scroll, and an orientation-aware layout picker. Dashboard sections (Keep Reading, On Deck, Recently Added/Read/Released/Updated) can be reordered or hidden per library.
- **Readers tuned for each platform**: DIVINA handles LTR/RTL/vertical/Webtoon with spreads, zoom, configurable tap zones, quick jumps, exports, tvOS remote gestures, and a dedicated macOS reader window. EPUB on iOS/iPadOS/macOS adds offline downloads, custom fonts/themes, pagination, column layouts, TOC navigation, auto layout, incognito mode, and optional image-first rendering. tvOS currently supports DIVINA.
- **Real-time admin & updates**: Edit metadata, manage API keys, collections/read lists, trigger scans/analyses per library or globally, cancel queued tasks, and view metrics. Server-Sent Events keep dashboards, thumbnails, queues, and sessions in sync with optional notifications and auto-refresh toggles.
- **Caching built in**: Three-tier caches for pages, book files, and thumbnails expose adjustable budgets, live size/file counts, one-tap clearing, and automatic cleanup so recent pages and EPUB downloads reopen offline.
- **Native polish**: Accent colors, Webtoon width controls, tap-zone hints, keyboard shortcuts, incognito reading, in-app log viewer with filtering, and focus-friendly tvOS navigation keep the app feeling at home on every device.

---

## 🧭 Overview

- Shared SwiftUI scenes cover browsing, reading, dashboards, and admin tasks across iPhone, iPad, Mac, and Apple TV.
- SwiftData stores Komga instances, libraries, and custom fonts so server profiles, cache budgets, and dashboard preferences stay local per device.
- Services centralize API access, authentication, caching, SSE subscriptions, and error handling for consistent behavior on every platform.
- Local storage keeps profiles, recent activity, and cached downloads so switching servers does not reset your state.

---

## 🚀 Getting Started

1. Prerequisites: iOS 17.0+, macOS 14.0+, tvOS 17.0+, Xcode 15.0+.
2. Clone and open the project:
   ```bash
   git clone https://github.com/everpcpc/KMReader.git
   cd KMReader
   open KMReader.xcodeproj
   ```
3. Build and run on your target device or simulator, then enter your Komga server URL and credentials.

Build helpers (optional):

- `make build-ios`, `make build-macos`, `make build-tvos` for device builds.
- `make build-ios-ci`, `make build-macos-ci`, `make build-tvos-ci` for code-signing-free simulator builds.
- `make release` archives/exports all platforms; see `Makefile` for archive/export targets.

> tvOS currently supports DIVINA. EPUB and Webtoon modes are available on iOS/iPadOS/macOS.

---

## 🔌 Compatibility

- Requires **Komga 1.19.0** or later.
- Works with **Komga API v1 and v2** (authentication, libraries/series/books, reading progress/pages, collections, and read lists).
- SSE keeps dashboards and task analytics synchronized with toggles for auto-refresh and connection notifications.

---

## 🛠️ Debugging

- Verbose API logging is available in Xcode Console or Console.app (process `Komga`, subsystem `Komga`, category `API`).
- Sample entry:
  ```
  📡 GET https://your-server.com/api/v2/users/me
  ✅ 200 GET https://your-server.com/api/v2/users/me (45.67ms)
  ```

---

## 🛣️ Roadmap

- Handoff support
- Live Text / automatic page translation

---

## 📄 License

Released under the terms of the [LICENSE](LICENSE) file.

---

## 💬 Discuss

Join the discussion on [Discord](https://discord.gg/komga-678794935368941569).

---

<div align="center">

**Made with ❤️ for the Komga community**
⭐ Star this repo if it helps you keep your library in sync!

</div>
