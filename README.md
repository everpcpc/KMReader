<div align="center">

# 📚 KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**A beautiful, native iOS client for [Komga](https://github.com/gotson/komga)**

*A media server for comics, mangas, BDs, and magazines*

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

</div>

---

## ✨ Features

### 🔐 Authentication
- Secure login with session management
- Authentication activity tracking
- Role-based access control

### 📚 Browsing
- **Unified Browse View**: Series, Books, Collections, and Read Lists in one place
- **Layout Modes**: Grid and List views with customizable columns (1-8)
- **Search & Filter**: Full-text search, library filtering, and advanced filters
- **Sorting**: Multiple sort options with persistent preferences

### 📖 Reading Experience
- **Multiple Reading Modes**: LTR, RTL, Vertical, and Webtoon (adjustable width 50%-100%)
- **Reader Features**: Pinch to zoom (1x-4x), swipe navigation, tap zones, auto-hide controls
- **Progress Tracking**: Automatic sync, resume from last page, reading status indicators
- **Save Pages**: Save to Photos or Files (JPEG, PNG, HEIF, WebP)

### 📊 Dashboard & History
- **Dashboard**: Keep Reading, On Deck, Recently Added/Updated content
- **History**: Recently read books with infinite scroll and quick resume

### ⚙️ Settings
- **Appearance**: Theme colors, browse columns, card display options
- **Reader**: Tap zone hints, background colors, webtoon width
- **Cache**: Configurable disk cache (512MB-8GB), manual clear
- **Management**: Library operations, server info, metrics, account settings

### 💾 Performance
- Two-tier caching (memory + disk)
- Smart image loading with WebP support
- Intelligent page preloading
- Automatic cache cleanup

---

## 🏗️ Architecture

Built with **SwiftUI** following **MVVM** pattern:

- **Models**: Library, Series, Book, Collection, ReadList, etc.
- **Services**: APIClient, AuthService, LibraryService, SeriesService, BookService, ImageCache, ErrorManager
- **ViewModels**: AuthViewModel, LibraryViewModel, SeriesViewModel, BookViewModel, ReaderViewModel, etc.
- **Views**: Login, Dashboard, Browse, History, Settings, Reader (multiple modes), Detail views

---

## 🚀 Getting Started

### Prerequisites
- iOS 17.0+
- Xcode 15.0+
- A running [Komga server](https://github.com/gotson/komga)

### Installation

1. Clone and open in Xcode:
   ```bash
   git clone https://github.com/yourusername/KMReader.git
   cd KMReader
   open KMReader.xcodeproj
   ```

2. Build and run on iOS 17+ device or simulator

3. On first launch, enter your Komga server URL, username, and password

---

## 🔌 API Compatibility

Compatible with **Komga API v1 and v2**:
- ✅ User Authentication (API v2)
- ✅ Libraries, Series, Books (API v1)
- ✅ Reading Progress & Book Pages (API v1)
- ✅ Collections & Read Lists (API v1)

---

## 🛠️ Debugging

The app includes comprehensive API logging using Apple's unified logging system (OSLog).

**View logs in Xcode Console or Console.app:**
- Filter by process: "Komga" or subsystem: "Komga"
- Category: "API"

**Log Format:**
```
📡 GET https://your-server.com/api/v2/users/me
✅ 200 GET https://your-server.com/api/v2/users/me (45.67ms)
```

---

## 🛣️ Roadmap

- [ ] Two-page spread for landscape mode
- [ ] Skip cover option for two-page spread
- [ ] Live Text support
- [ ] EPUB reader

---

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

---

<div align="center">

**Made with ❤️ for the Komga community**

⭐ Star this repo if you find it useful!

</div>
