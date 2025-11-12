# Komga iOS Client

A native iOS client for Komga - a media server for comics/mangas/BDs/magazines.

## Features

- 🔐 User authentication with Komga server
- 📚 Browse libraries, series, and books
- 📖 Read comics with an intuitive reader
  - Pinch to zoom
  - Swipe between pages
  - Progress tracking
- 📊 View reading progress
- 🎯 "On Deck" - Continue reading in-progress books
- 🔄 Pull to refresh
- 💾 Automatic image caching
- 📝 Comprehensive API logging
  - Request URL and method
  - Response status codes
  - Request duration
  - Data transfer size

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
- `LibraryListView` - Browse libraries
- `SeriesListView` - Browse series in a library
- `SeriesDetailView` - Series details with books list
- `BookReaderView` - Full-screen comic reader
- `OnDeckView` - In-progress books
- `SettingsView` - User settings

## Setup

1. Open the project in Xcode 15+
2. Build and run on iOS 17+ device or simulator
3. On first launch, enter:
   - Your Komga server URL (e.g., `http://192.168.1.100:25600`)
   - Username
   - Password

## API Compatibility

This client is compatible with Komga API v1 and v2. It supports:

- ✅ User authentication (API v2)
  - Login with remember-me support
  - Logout
  - Current user info
- ✅ Libraries (API v1)
- ✅ Series browsing (all, new, updated) (API v1)
  - Mark as read/unread
- ✅ Books (API v1)
  - Mark as read/unread
- ✅ Reading progress tracking (API v1)
- ✅ Thumbnails (API v1)
- ✅ Book pages (API v1)
- ✅ Collections (API v1)
- ✅ Read Lists (API v1)
- ⏳ Search (coming soon)
- ⏳ EPUB reader (coming soon)

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
