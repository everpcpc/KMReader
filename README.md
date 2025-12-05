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

[![Download on the App Store](https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us?size=250x83&releaseDate=1733011200)](https://apps.apple.com/app/id6755198424)

</div>

---

## ✨ Highlights

- **Guided onboarding & unlimited servers**: First launch drops straight into Komga login, stores unlimited instances with custom names/roles, records authentication history (IP, user-agent, API key), and clears cached credentials or downloads when removing a server.
- **Adaptive browse & dashboards**: Series, Books, Collections, and Read Lists share one browse surface with search, filters, orientation-aware grid/list layouts, infinite scroll, and customizable dashboard sections (Keep Reading, On Deck, Recently Added/Read/Released/Updated) per library.
- **Deep metadata & inline editing**: Rich series and collection pages expose release timelines, directions, publishers, genres, tags, alternate titles, creators, and related collections alongside actions for edit, analyze, refresh metadata, mark read/unread, add/remove collections, and delete with confirmations.
- **Two optimized readers**: DIVINA covers LTR/RTL/vertical/Webtoon on iOS/iPadOS/macOS/tvOS with dual-page spreads, pinch zoom, configurable tap zones, quick page jumps, exports, tvOS remote gestures, and a macOS reader window. EPUB reader (iOS/iPadOS/macOS) keeps titles offline or incognito with custom fonts, themes, pagination, column layouts, TOC navigation, and an optional image-first mode.
- **Live admin & monitoring**: Edit metadata, manage collections/read lists, trigger scans or analyses per library or globally, cancel outstanding tasks, and inspect disk usage plus per-library metrics while SSE pushes live updates for dashboards, task queues, thumbnails, and session expirations with opt-in notifications.
- **Smart caching & native polish**: Three-tier caches for pages, book files, and thumbnails expose adjustable budgets, live size/file counts, one-tap clearing, and automatic cleanup so recently viewed pages and EPUB downloads reopen offline. Accent colors, Webtoon width controls, tap-zone hints, keyboard shortcuts, focus-friendly tvOS navigation, and incognito reading keep everything feeling native.

---

## 🧭 Overview

- Scenes for browsing, readers, dashboard, and admin tasks keep navigation predictable across iPhone, iPad, Mac, and Apple TV.
- SwiftData stores Komga instances, libraries, and custom fonts so every server profile, cache budget, and dashboard preference stays local to the device.
- Shared services handle API access, authentication, caching, SSE subscriptions, and error surfaces for consistent behavior on every platform.
- Local storage remembers each Komga profile, last activity, and cached downloads so switching servers never means losing state.

---

## 🚀 Getting Started

1. Install the prerequisites (iOS 17.0+/macOS 14.0+/tvOS 17.0+ and Xcode 15.0+).
2. Clone and open the project:
   ```bash
   git clone https://github.com/everpcpc/KMReader.git
   cd KMReader
   open KMReader.xcodeproj
   ```
3. Build and run on your target device or simulator, then enter your Komga server URL plus credentials.

> tvOS currently supports DIVINA reading; EPUB and Webtoon modes are available on iOS/iPadOS/macOS.

---

## 🔌 Compatibility

- Works with **Komga API v1 and v2** (authentication, libraries/series/books, reading progress/pages, collections, and read lists).
- SSE keeps dashboards and task analytics synchronized, with toggles for auto-refresh and connection notifications.

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
- Offline reading enhancements
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
