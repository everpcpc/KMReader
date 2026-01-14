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

- **Multi-server vault**: Save unlimited Komga servers with password or API key authentication.
- **Cloud-drive-like offline**: Background downloads with Live Activity on iOS. Offline policies (manual, latest, all) per series. Read lists and collections stay available offline. Progress syncs when connection restores.
- **Browse + dashboards**: Search, filters, grid/list layouts. Customizable dashboard sections per library with faster first paint and stable refresh.
- **Readers**: DIVINA (LTR/RTL/vertical/Webtoon) with spreads, zoom, customizable tap zones, page isolation, and transition styles. EPUB with custom fonts/themes, pagination, TOC navigation, and incognito mode. Live Text support with shake-to-open on iOS.
- **Privacy protection**: Optional blur overlay to protect reading content from prying eyes.
- **Admin tools**: Metadata editing, scans, task management, live metrics via SSE, and an in-app log viewer with filtering.
- **Caching**: Three-tier caches (pages, books, thumbnails) with adjustable limits and auto-cleanup.

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

## 💬 Discuss

Join the discussion on [Discord](https://discord.gg/komga-678794935368941569).

---

<div align="center">

**Made with ❤️ for the Komga community**

⭐ Star this repo if it helps you keep your library in sync!

</div>
