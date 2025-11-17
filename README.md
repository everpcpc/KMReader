# KMReader

A native iOS client for Komga - a media server for comics/mangas/BDs/magazines.

## Features

### 🔐 Authentication
- User login with Komga server
- Remember-me support
- Session management
- User profile display

### 📚 Browsing
- **Libraries**: Browse all libraries with filtering
- **Series**: Browse series by library with grid layout
- **Books**: View books within a series
- **Series Filtering & Sorting**:
  - Filter by read status (All, Read, Unread, In Progress)
  - Filter by series status (All, Ongoing, Ended, Hiatus, Cancelled)
  - Sort by: Name, Date Added, Date Updated, Date Read, Release Date, Folder Name, Books Count, Random
  - Sort direction: Ascending/Descending (except Random)
  - Library filtering across all views
- **Series Details**:
  - Series metadata (title, status, age rating, language, publisher)
  - Authors and roles (Writer, Artist, Colorist, Letterer, etc.)
  - Genres and tags
  - Summary
  - Reading direction
  - Book count and unread count
  - Release date
  - Books list with reading progress indicators
  - Book list sorting (ascending/descending by book number)

### 📖 Reading Experience
- **Multiple Reading Modes**:
  - **LTR (Left-to-Right)**: Traditional comic reading with horizontal page navigation
  - **RTL (Right-to-Left)**: Manga reading style with reverse horizontal navigation
  - **Vertical**: Vertical page scrolling for vertical comics
  - **Webtoon**: Continuous vertical scroll with adjustable page width (50%-100%)
  - Automatic reading direction detection from series metadata
  - Manual reading mode selection during reading
- **Reader Features**:
  - Pinch to zoom (1x to 4x)
  - Double-tap to zoom in/out
  - Drag to pan when zoomed
  - Swipe/tap navigation between pages
  - Tap zones for page navigation (left/right or top/bottom depending on mode)
  - Center tap to toggle controls
  - Auto-hide controls (3 seconds, disabled at end page)
  - Reading direction picker (accessible from reader controls)
  - Page counter display (current page / total pages)
  - Progress slider for quick navigation
  - End page view with next book navigation
  - Next book auto-detection and navigation
  - Save current page to Photos (JPEG, PNG, HEIF formats supported)
  - Save current page to Files app (via document picker)
  - Context menu on page images for quick save to Photos
- **Progress Tracking**:
  - Automatic progress sync to server
  - Resume from last read page on book open
  - Mark as read/unread
  - Reading status indicators (UNREAD, IN_PROGRESS, READ)
  - Progress updates on every page change
- **Performance**:
  - Intelligent page preloading (1-3 pages ahead based on reading mode)
  - Two-tier image caching system (disk + memory)
  - Automatic image downscaling for large images to prevent OOM
  - LRU memory cache with automatic cleanup
  - Thumbnail caching for series and books
  - Smooth scrolling and transitions
  - Efficient memory management with automatic cache eviction

### 📊 Dashboard
- **Keep Reading**: Books currently in progress (sorted by last read date)
- **On Deck**: Next books to read in series
- **Recently Added Books**: Latest additions to libraries
- **Recently Added Series**: New series added to libraries
- **Recently Updated Series**: Recently updated series
- **Library Filter**: Filter dashboard content by library
- **Pull to Refresh**: Manual refresh button to reload all sections
- **Empty State**: Helpful message when no content is available

### 📜 History
- Recently read books with relative timestamps (e.g., "2h ago", "Yesterday", "3 days ago")
- Reading progress display for each book
- Book metadata (series title, book title, page count, book number)
- Library filtering
- Infinite scroll with automatic pagination
- Quick access to resume reading
- Last read date display
- Pull to refresh support

### ⚙️ Settings
- **Appearance**:
  - Theme color selection (6 color options)
- **Reader**:
  - Webtoon page width adjustment (50% - 100%)
- **Cache**:
  - View disk cache size and cached image count
  - Adjust maximum disk cache size (512MB - 8GB, default 2GB)
  - Clear disk cache manually
  - Automatic cache cleanup when limit is exceeded
- **Account**:
  - User email and roles display
  - Logout

### 🔍 Search & Filtering
- **Book Search**:
  - Filter by read status (UNREAD, IN_PROGRESS, READ)
  - Filter by library
  - Filter by series
  - Combined filters (library + read status)
- **Series Filtering** (in Browse view):
  - Filter by read status (All, Read, Unread, In Progress)
  - Filter by series status (All, Ongoing, Ended, Hiatus, Cancelled)
  - Sort by multiple fields with ascending/descending order
  - Random sorting option
  - Persistent filter preferences

### 💾 Performance & Caching
- **Two-Tier Image Caching System**:
  - **Disk Cache**: Stores raw image data (configurable, default 2GB, range 512MB-8GB) to avoid re-downloading
    - Persistent across app restarts
    - Organized by book ID for efficient management
    - Automatic cleanup of oldest files when limit is reached
    - Manual cache clearing from settings
    - Cache size monitoring and statistics
  - **Memory Cache**: Stores decoded images (up to 50 images, 200MB)
    - LRU (Least Recently Used) eviction policy
    - Automatic cleanup on memory warnings
    - Fast instant display for recently viewed pages
- **Smart Image Loading**:
  - Load order: Memory cache → Disk cache → Network download
  - Automatic downscaling of large images to screen size (prevents OOM)
  - Background image decoding to avoid UI blocking
  - Progressive loading with placeholder states
- **Page Preloading**:
  - Intelligent preloading based on reading mode
  - Automatic cleanup of pages far from current position
  - Concurrent loading for better performance
- **Thumbnail Caching**: Fast thumbnail loading for series and books
- **Memory Management**:
  - Automatic cache size limits
  - Memory warning handling
  - Efficient cleanup of unused resources
  - User-configurable cache size limits

### 📝 API Logging
- Comprehensive API request/response logging
- Request URL and method
- Response status codes
- Request duration
- Data transfer size
- Detailed error information for debugging

## Architecture

The app is built using modern SwiftUI and follows the MVVM pattern:

### Models
- `Library` - Represents a library on the Komga server
- `Series` - A series of books/comics
- `Book` - Individual books with metadata
- `Page` - Paginated API responses
- `Collection` & `ReadList` - Book collections and reading lists

### Services
- `APIClient` - Core HTTP client with authentication
- `AuthService` - User authentication and session management
- `LibraryService` - Library operations
- `SeriesService` - Series browsing and operations
- `BookService` - Book operations and reading
- `CollectionService` & `ReadListService` - Collection/ReadList operations
- `ImageCache` - Two-tier image caching system (disk + memory) with LRU eviction

### ViewModels
- `AuthViewModel` - Authentication state management
- `LibraryViewModel` - Libraries data
- `SeriesViewModel` - Series browsing with thumbnail caching
- `BookViewModel` - Books data with thumbnail caching
- `ReaderViewModel` - Reading experience with page caching

### Views
- `LoginView` - Server and credential input
- `DashboardView` - Home screen with recommendations and library filtering
- `BrowseView` - Browse series with advanced filtering and sorting options
- `SeriesListView` - Grid layout for browsing series with infinite scroll
- `SeriesDetailView` - Comprehensive series details with metadata and books list
- `BookReaderView` - Full-screen comic reader with multiple reading modes
- `HorizontalPageView` - LTR/RTL horizontal page navigation
- `VerticalPageView` - Vertical page scrolling
- `WebtoonReaderView` - Webtoon-style continuous vertical scroll reader
- `PageImageView` - Individual page display with zoom and pan, context menu for saving images
- `ReaderControlsView` - Reader controls overlay (navigation, progress, settings, save to Photos/Files)
- `EndPageView` - End of book view with next book navigation
- `SaveImageButton` - Reusable component for saving images to Photos
- `HistoryView` - Reading history with infinite scroll
- `SettingsView` - User settings and preferences
- `BookCardView` - Book card component with thumbnail
- `BookRowView` - Book row component for list views
- `SeriesCardView` - Series card component with thumbnail and unread badge

## Setup

1. Open the project in Xcode 15+
2. Build and run on iOS 17+ device or simulator
3. On first launch, enter:
   - Your Komga server URL (e.g., `http://192.168.1.100:25600`)
   - Username
   - Password

## API Compatibility

This client is compatible with Komga API v1 and v2. It supports:

- ✅ **User Authentication (API v2)**
  - Login with remember-me support
  - Logout
  - Current user info
- ✅ **Libraries (API v1)**
  - List all libraries
  - Library filtering
- ✅ **Series (API v1)**
  - Browse all series
  - Browse new series
  - Browse updated series
  - Series details with full metadata
  - Series thumbnails
  - Mark series as read/unread
- ✅ **Books (API v1)**
  - List books in a series
  - Book details
  - Book search with filters (read status, library, series)
  - Recently added books
  - Recently read books
  - On Deck books
  - Book thumbnails
  - Mark books as read/unread
- ✅ **Reading Progress (API v1)**
  - Track reading progress
  - Update progress automatically
  - Resume from last page
  - Reading status (UNREAD, IN_PROGRESS, READ)
- ✅ **Book Pages (API v1)**
  - Get page list
  - Download page images
  - Two-tier page caching (disk + memory)
  - Automatic image optimization and downscaling
- ✅ **Collections (API v1)**
  - Collection support (models and services)
- ✅ **Read Lists (API v1)**
  - Read list support (models and services)

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+
- A running Komga server

## Debugging

The app includes comprehensive API logging using Apple's unified logging system (OSLog). To view logs:

1. **In Xcode Console:**
   - Run the app from Xcode
   - View logs in the console at the bottom

2. **In Console.app:**
   - Open Console.app on your Mac
   - Connect your device
   - Filter by process name: "Komga" or subsystem: "Komga"
   - Category: "API"

**Log Format:**
```
📡 GET https://your-server.com/api/v2/users/me
✅ 200 GET https://your-server.com/api/v2/users/me (45.67ms)
📡 GET https://your-server.com/api/v1/series/123/thumbnail [Data]
✅ 200 GET https://your-server.com/api/v1/series/123/thumbnail (123.45ms, 245 KB)
```

**Log Symbols:**
- 📡 Request sent
- ✅ Successful response (200-299)
- ❌ Error response (400+) or network error
- 🔒 Unauthorized (401)
- ⚠️ Warning (e.g., empty response)

**Detailed Error Information:**

When a decoding error occurs, the log will show:
- Missing keys and their paths
- Type mismatches
- Value not found errors
- First 1000 characters of the response data for debugging

This helps quickly identify API compatibility issues between different Komga versions.

## Reference

This iOS client is based on the official [Komga Web UI](https://github.com/gotson/komga) and implements similar functionality in a native iOS experience.
