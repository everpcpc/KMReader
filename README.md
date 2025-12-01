<div align="center">

# 📚 KMReader

<div>
  <img src="icon.svg" alt="KMReader Icon" width="128" height="128">
</div>

**A beautiful, multi-server native iOS, macOS, and tvOS client for [Komga](https://github.com/gotson/komga) with comic and EPUB readers**

_A media server for comics, mangas, BDs, and magazines_

[![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)](https://www.apple.com/ios/)
[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![tvOS](https://img.shields.io/badge/tvOS-17.0+-blue.svg)](https://www.apple.com/tv/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)
[![Xcode](https://img.shields.io/badge/Xcode-15.0+-blue.svg)](https://developer.apple.com/xcode/)

</div>

---

## ✨ Features

### 🔐 Authentication & Servers

- Guided onboarding flow with a dedicated landing screen that walks new installs straight into server setup
- Secure login with session management and device-scoped configuration
- Multi-server vault that lets you rename instances, see URLs and roles at a glance, swipe to edit/delete, and clear caches when removing a server
- Quick session insight in Settings with email and admin indicators for the active account
- Detailed authentication activity log with infinite scroll, IP/User-Agent/API key metadata, and pull-to-refresh
- Role-based access control automatically unlocks admin-only tools and hides them for regular users

### 📚 Browsing & Organization

- **Unified Browse View**: Series, Books, Collections, and Read Lists in one place
- **Layout Modes**: Grid and List views with customizable columns
- **Orientation-Aware Layout**: Separate portrait and landscape column counts plus toggles for card titles and thumbnail aspect ratios
- **Advanced Search**: Full-text search across your entire library
- **Powerful Filtering**: Filter by library, read status, series status, and more
- **Flexible Sorting**: Multiple sort options (title, date, file size, page count, etc.) with persistent preferences
- **Collections**: Create and manage collections to organize related series
- **Read Lists**: Build custom reading lists for curated experiences

### 📖 Reading Experience

- **Supported Formats**:
  - **DIVINA** (comics, manga, BDs): Full-featured comic reader with multiple reading modes
  - **EPUB**: Advanced EPUB reader with comprehensive customization
- **Multiple Reading Modes** (DIVINA):
  - Left-to-Right (LTR) for Western comics
  - Right-to-Left (RTL) for manga
  - Vertical scrolling for traditional manga
  - Webtoon mode with adjustable width (iOS/iPadOS only)
- **Page Layouts** (DIVINA):
  - Single page mode
  - Dual page mode (landscape orientation) for two-page spreads
  - Skip cover option in dual page mode
- **Comic Reader Features** (DIVINA):
  - Pinch to zoom for fine detail (iOS/iPadOS/macOS)
  - Swipe navigation with customizable tap zones
  - Auto-hide controls for immersive reading
  - Page jump functionality with visual page counter
  - Dynamic reading direction switching
  - **macOS**: Dedicated reader window for enhanced reading experience
  - **tvOS**: Optimized for remote control navigation with focus-based interface
- **EPUB Reader** (iOS/iPadOS/macOS only):
  - Full-book EPUB downloads cached for offline and incognito reading
  - Pick any installed typeface or stick with the publisher's choice
  - Adjustable font size slider with paged or continuous scroll modes
  - Auto, single, or dual-column layouts tuned for iPad and macOS
  - System, light, sepia, or dark themes with automatic switching
  - Table of contents browser with real-time progress indicator
  - Optional "image view" mode for compatible EPUBs when you prefer comic-style rendering
- **Progress Tracking**:
  - Automatic synchronization across all devices
  - Resume from last page
  - Reading status indicators (read, unread, in-progress)
  - Incognito mode: Read without updating progress (available for both DIVINA and EPUB)
- **Save Pages**: Save favorite pages to Photos or Files in multiple formats (JPEG, PNG, HEIF, WebP)

### 📊 Dashboard & History

- **Dashboard Sections** (Customizable):
  - Keep Reading: Quick access to books you're currently reading
  - On Deck: Next books ready to read in your series
  - Recently Added Books: Newly added content
  - Recently Read Books: Books you've recently finished
  - Recently Released Books: Books sorted by release date
  - Recently Added Series: New series in your library
  - Recently Updated Series: Series with new content
- **Dashboard Customization**:
  - Show or hide any dashboard section
  - Reorder sections to match your preferences
  - Filter dashboard content by selected libraries
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
  - Delete libraries (with name confirmation for safety)
  - Multi-select libraries for batch operations
  - Global operations for all libraries
  - One-tap sheets for individual libraries plus toolbar actions to scan or empty trash across every library
  - Library metrics and analytics

### 📡 Server Insights & Monitoring

- **Server Info**: View Komga build metadata, git SHA, Java runtime, and OS details directly from the actuator endpoint
- **Metrics Dashboard**: Inspect all-library disk usage, counts for series/books/collections/read lists/sidecars, and drill down per library
- **Task Analytics**: Track executed tasks, duration per task type, and surface API errors inline for fast troubleshooting
  - View tasks executed count by type
  - Monitor total execution time per task type
  - Cancel all running tasks with confirmation
  - Error handling for metrics with inline error messages
- **Real-Time Updates (SSE)**: Stay synchronized with your Komga server through Server-Sent Events
  - Instant notifications when libraries, series, books, collections, or read lists are added, changed, or deleted
  - Real-time read progress updates across all devices
  - Live task queue status monitoring with automatic updates
  - Thumbnail generation progress updates for books, series, collections, and read lists
  - Session expiration notifications
  - **Automatic Dashboard Refresh**: Dashboard automatically refreshes when content changes via SSE events with smart debouncing (5 seconds) to ensure the last event always triggers a refresh
  - Toggle real-time updates on or off in Settings with a dedicated SSE settings page
  - Optional connection status and task completion notifications
  - Independent control over auto-refresh behavior (can disable dashboard auto-refresh while keeping other SSE features enabled)
  - Automatic reconnection on connection loss

### ⚙️ Settings & Customization

- **Appearance**:
  - Pick a favorite accent color to theme the app
  - Adjust portrait and landscape column counts independently
  - Toggle card details like series titles and thumbnail aspect ratios
- **Dashboard Settings**:
  - Customize which dashboard sections are visible
  - Reorder sections to match your reading workflow
  - Filter dashboard content by specific libraries
- **Reader Settings**:
  - Tap zone hints toggle
  - Reader background colors (system, black, white, gray)
  - Page layout selection (single/dual page)
  - Skip cover in dual page mode
  - Webtoon page width adjustment
  - EPUB preferences: fonts, font size, pagination, layout, theme presets (system/light/sepia/dark), and optional image-view fallback
- **Cache Management**:
  - **Three-tier caching system**:
    - Page cache: Adjustable disk cache for reading pages
    - Book file cache: Stores complete EPUB files for offline access
    - Thumbnail cache: Fast thumbnail loading for browse views
  - Real-time cache size and file count display for each cache type
  - Individual manual cache clearing for each cache type
  - Automatic cache cleanup when page cache limit is exceeded
- **Servers & Accounts**:
  - Add/edit/delete Komga instances, rename them, and switch instantly between saved sessions
  - Stored credentials remain on-device and can be cleared by deleting a server entry
  - View user information, admin status, and authentication activity logs before logging out
- **Real-Time Updates**:
  - Dedicated SSE settings page with connection and notification controls
  - Enable or disable Server-Sent Events (SSE) for real-time synchronization
  - Toggle dashboard auto-refresh independently (can disable auto-refresh while keeping other SSE features)
  - Toggle connection status and task completion notifications
  - Automatic reconnection on connection loss
  - Real-time updates for content changes, read progress, task queue status, and thumbnail generation
  - Smart debouncing ensures dashboard refreshes after events settle (5 seconds), guaranteeing the last event always triggers a refresh

### 💾 Performance & Optimization

- **Three-Tier Caching System**: Intelligent memory and disk caching for pages, book files, and thumbnails
- **WebP Support**: Optimized image loading with WebP format support
- **Intelligent Preloading**: Automatic page preloading for seamless reading
- **Offline Capability**: Access recently viewed content when offline (pages and EPUB files)
- **Efficient Image Loading**: Smart image loading with progressive enhancement
- **EPUB Cache**: Whole-book EPUB downloads stored securely for instant reopen and offline support
- **Separate Cache Management**: Independent control over page, book file, and thumbnail caches with adjustable limits (512MB-8GB for page cache) and live size/file counters
- **Server-Aware Cleanup**: Removing a saved server clears its cached pages, thumbnails, and EPUB data automatically
- **Real-Time Cache Monitoring**: View current cache sizes and file counts for each cache type in Settings

---

## 🧭 Design Overview

- Clear separation between browsing, reading, settings, and admin areas keeps navigation intuitive
- Local storage remembers every Komga server profile so you can switch sessions instantly
- Reusable services centralize networking, caching, and error handling for predictable behavior
- Dedicated views for authentication, dashboards, and readers ensure consistent experiences across iPhone, iPad, Mac, and Apple TV

## 🚀 Getting Started

### Prerequisites

- iOS 17.0+, macOS 14.0+, or tvOS 17.0+
- Xcode 15.0+
- A running [Komga server](https://github.com/gotson/komga)

### Installation

1. Clone and open in Xcode:

   ```bash
   git clone https://github.com/everpcpc/KMReader.git
   cd KMReader
   open KMReader.xcodeproj
   ```

2. Build and run on iOS 17+ device/simulator, macOS 14.0+, or tvOS 17.0+

3. On first launch, enter your Komga server URL, username, and password

**Note**: tvOS supports DIVINA (comic) reading only. EPUB reading and Webtoon mode are available on iOS/iPadOS/macOS.

---

## 🔌 API Compatibility

Compatible with **Komga API v1 and v2**:

- ✅ User Authentication (API v2)
- ✅ Libraries, Series, Books (API v1)
- ✅ Reading Progress & Book Pages (API v1)
- ✅ Collections & Read Lists (API v1)

---

## 🛠️ Debugging

The app includes comprehensive API logging.

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

- [ ] Offline reading
- [ ] Live Text support / automatic page translation

---

## 📄 License

This project is licensed under the terms specified in the [LICENSE](LICENSE) file.

---

<div align="center">

**Made with ❤️ for the Komga community**

⭐ Star this repo if you find it useful!

</div>
