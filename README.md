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

- **Guided onboarding & multi-server vault**: first launch walks straight into Komga login, stores unlimited servers with custom names/roles, logs authentication history, and wipes cached data on removal.
- **Unified library**: browse Series, Books, Collections, and Read Lists with grid/list layouts, orientation-aware columns, rich filters, and infinite-scroll history. Personalize dashboard sections (Keep Reading, On Deck, Recently Added/Read/Released/Updated) per library.
- **Powerful readers**: DIVINA supports LTR/RTL/vertical/Webtoon (dual pages, pinch zoom, custom tap zones, page export, macOS window, tvOS remote). EPUB reader (iOS/iPadOS/macOS) offers offline downloads, custom fonts/themes/layouts, column modes, TOC navigation, and optional image-view fallback. Incognito reading is available in both engines.
- **Admin & monitoring**: edit metadata, manage collections/read lists, trigger scans/analyses per library or globally, and inspect disk usage plus task analytics. Live Server-Sent Events keep dashboards, task queues, thumbnails, and sessions in sync with opt-in notifications.
- **Smart caching & offline access**: dedicated caches for pages, book files, and thumbnails with adjustable limits, live size/file counters, manual clearing, automatic cleanup, and offline reopening for recent pages/EPUB files.
- **Native Apple touches**: accent color and layout controls, keyboard shortcuts, adjustable Webtoon width, tap zone hints, tvOS focus navigation, and a dedicated macOS reader window.

---

## 🧭 Overview

- Clean separation between browsing, reading, settings, and admin tools keeps navigation predictable.
- Reusable services centralize networking, caching, SSE handling, and error reporting for identical behavior on every device.
- Local storage remembers every Komga profile so you can jump between servers instantly.

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
