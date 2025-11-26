<div align="center">

# 📚 KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**A beautiful, native iOS and macOS client for [Komga](https://github.com/gotson/komga) with comic and EPUB readers**

_A media server for comics, mangas, BDs, and magazines_

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

</div>

---

## ✨ Features

### 🔐 Authentication

- Secure login with session management
- Authentication activity tracking
- Role-based access control (Admin and User roles)

### 📚 Browsing & Organization

- **Unified Browse View**: Series, Books, Collections, and Read Lists in one place
- **Layout Modes**: Grid and List views with customizable columns (1-8)
- **Advanced Search**: Full-text search across your entire library
- **Powerful Filtering**: Filter by library, read status, series status, and more
- **Flexible Sorting**: Multiple sort options (title, date, file size, page count, etc.) with persistent preferences
- **Collections**: Create and manage collections to organize related series
- **Read Lists**: Build custom reading lists for curated experiences

### 📖 Reading Experience

- **Multiple Reading Modes**:
  - Left-to-Right (LTR) for Western comics
  - Right-to-Left (RTL) for manga
  - Vertical scrolling for traditional manga
  - Webtoon mode with adjustable width (50%-100%) (iOS only)
- **Page Layouts**:
  - Single page mode
  - Dual page mode (landscape orientation) for two-page spreads
  - Skip cover option in dual page mode
- **Reader Features**:
  - Pinch to zoom (1x-4x magnification)
  - Swipe navigation with customizable tap zones
  - Auto-hide controls for immersive reading
  - Page jump functionality with visual page counter
  - Dynamic reading direction switching
  - **macOS**: Dedicated reader window for enhanced reading experience
- **EPUB Reader**:
  - Full-book EPUB downloads cached for offline and incognito reading
  - Pick any installed typeface or stick with the publisher's choice
  - Adjustable font size slider with paged or continuous scroll modes
  - Auto, single, or dual-column layouts tuned for iPad and macOS
  - System, light, sepia, or dark themes with automatic switching
  - Table of contents browser with real-time progress indicator
- **Progress Tracking**:
  - Automatic synchronization across all devices
  - Resume from last page
  - Reading status indicators (read, unread, in-progress)
  - Incognito mode: Read without updating progress
- **Save Pages**: Save favorite pages to Photos or Files in multiple formats (JPEG, PNG, HEIF, WebP)

### 📊 Dashboard & History

- **Dashboard Sections**:
  - Keep Reading: Quick access to books you're currently reading
  - On Deck: Next books ready to read in your series
  - Recently Added Books: Newly added content
  - Recently Added Series: New series in your library
  - Recently Updated Series: Series with new content
- **History**:
  - Complete reading history with infinite scroll
  - Quick resume from history
  - Library-filtered history view

### 🛠️ Content Management (Admin)

- **Series Management**:
  - Edit series metadata
  - Mark series as read/unread
  - Analyze series for issues
  - Refresh metadata
  - Add to collections
  - Delete series
- **Book Management**:
  - Edit book metadata
  - Mark books as read/unread
  - Add to collections and read lists
  - Delete books
- **Library Operations**:
  - Scan library files (regular and deep scan)
  - Analyze libraries
  - Refresh metadata
  - Empty trash
  - Delete libraries
  - Global operations for all libraries

### ⚙️ Settings & Customization

- **Appearance**:
  - Multiple theme colors
  - Customizable browse columns
  - Card display options
- **Reader Settings**:
  - Tap zone hints toggle
  - Reader background colors (system, black, white, gray)
  - Page layout selection (single/dual page)
  - Skip cover in dual page mode
  - Webtoon page width adjustment (50%-100%)
  - EPUB preferences: fonts, font size, pagination, layout, and theme presets (system/light/sepia/dark)
- **Cache Management**:
  - Configurable disk cache size (512MB-8GB, adjustable in 256MB steps)
  - Real-time cache size and image count display
  - Manual cache clearing
  - Automatic cache cleanup when limit is exceeded
- **Server Management (Admin)**:
  - View server information
  - Monitor server metrics
  - Library management interface
- **Account**:
  - View user information
  - Check admin status
  - Authentication activity log
  - Logout functionality

### 💾 Performance & Optimization

- **Two-Tier Caching**: Intelligent memory and disk caching system
- **WebP Support**: Optimized image loading with WebP format
- **Intelligent Preloading**: Automatic page preloading for seamless reading
- **Offline Capability**: Access recently viewed content when offline
- **Efficient Image Loading**: Smart image loading with progressive enhancement
- **EPUB Cache**: Whole-book EPUB downloads stored securely for instant reopen and offline support

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

- iOS 17.0+ or macOS 14.0+
- Xcode 15.0+
- A running [Komga server](https://github.com/gotson/komga)

### Installation

1. Clone and open in Xcode:

   ```bash
   git clone https://github.com/everpcpc/KMReader.git
   cd KMReader
   open KMReader.xcodeproj
   ```

2. Build and run on iOS 17+ device/simulator or macOS 14.0+

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

- [ ] Live Text support / automatic page translation

---

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

---

<div align="center">

**Made with ❤️ for the Komga community**

⭐ Star this repo if you find it useful!

</div>
