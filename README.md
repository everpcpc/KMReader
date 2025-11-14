# Komga iOS Client

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
- **Series Details**:
  - Series metadata (title, status, age rating, language, publisher)
  - Authors and roles
  - Genres and tags
  - Summary
  - Reading direction
  - Book count and unread count
- **Library Filtering**: Filter content by library across all views

### 📖 Reading Experience
- **Multiple Reading Modes**:
  - **LTR (Left-to-Right)**: Traditional comic reading
  - **RTL (Right-to-Left)**: Manga reading style
  - **Vertical**: Vertical page scrolling
  - **Webtoon**: Continuous vertical scroll with adjustable page width
- **Reader Features**:
  - Pinch to zoom (1x to 4x)
  - Double-tap to zoom in/out
  - Drag to pan when zoomed
  - Swipe/tap navigation between pages
  - Tap zones for page navigation (left/right or top/bottom)
  - Center tap to toggle controls
  - Auto-hide controls (3 seconds)
  - Reading direction picker
  - Page counter display
  - Progress slider
- **Progress Tracking**:
  - Automatic progress sync
  - Resume from last read page
  - Mark as read/unread
  - Reading status indicators
- **Performance**:
  - Page preloading (3 pages ahead)
  - Image caching
  - Thumbnail caching
  - Smooth scrolling and transitions

### 📊 Dashboard
- **Keep Reading**: Books currently in progress
- **On Deck**: Next books to read
- **Recently Added Books**: Latest additions
- **Recently Added Series**: New series
- **Recently Updated Series**: Recently updated series
- **Library Filter**: Filter dashboard content by library

### 📜 History
- Recently read books with timestamps
- Reading progress display
- Library filtering
- Quick access to resume reading

### ⚙️ Settings
- **Appearance**:
  - Theme color selection (6 color options)
- **Reader**:
  - Webtoon page width adjustment (50% - 100%)
- **Account**:
  - User email and roles display
  - Logout

### 🔍 Search & Filtering
- Book search by read status (UNREAD, IN_PROGRESS, READ)
- Filter by library
- Filter by series
- Combined filters (library + read status)

### 💾 Performance & Caching
- Automatic image caching for pages
- Thumbnail caching for series and books
- Page preloading for smooth reading
- Efficient memory management

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

### ViewModels
- `AuthViewModel` - Authentication state management
- `LibraryViewModel` - Libraries data
- `SeriesViewModel` - Series browsing with thumbnail caching
- `BookViewModel` - Books data with thumbnail caching
- `ReaderViewModel` - Reading experience with page caching

### Views
- `LoginView` - Server and credential input
- `DashboardView` - Home screen with recommendations
- `LibraryListView` - Browse libraries
- `SeriesListView` - Browse series in a library
- `SeriesDetailView` - Series details with books list
- `BookReaderView` - Full-screen comic reader with multiple reading modes
- `WebtoonReaderView` - Webtoon-style continuous scroll reader
- `HistoryView` - Reading history
- `SettingsView` - User settings and preferences
- `BookCardView` - Book card component
- `SeriesCardView` - Series card component

## Setup

1. Open the project in Xcode 15+
2. Build and run on iOS 18+ device or simulator
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
  - Page caching
- ✅ **Collections (API v1)**
  - Collection support (models and services)
- ✅ **Read Lists (API v1)**
  - Read list support (models and services)

## Requirements

- iOS 18.0+
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
