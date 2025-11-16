//
//  ReaderViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import SwiftUI

enum ReadingDirection: CaseIterable, Hashable {
  case ltr
  case rtl
  case vertical
  case webtoon

  static func fromString(_ direction: String) -> ReadingDirection {
    switch direction.uppercased() {
    case "LEFT_TO_RIGHT":
      return .ltr
    case "RIGHT_TO_LEFT":
      return .rtl
    case "VERTICAL":
      return .vertical
    case "WEBTOON":
      return .webtoon
    default:
      return .ltr
    }
  }

  var displayName: String {
    switch self {
    case .ltr:
      return "LTR"
    case .rtl:
      return "RTL"
    case .vertical:
      return "Vertical"
    case .webtoon:
      return "Webtoon"
    }
  }

  var icon: String {
    if #available(iOS 18.0, *) {
      switch self {
      case .ltr:
        return "inset.filled.trailinghalf.arrow.trailing.rectangle"
      case .rtl:
        return "inset.filled.leadinghalf.arrow.leading.rectangle"
      case .vertical:
        return "rectangle.portrait.bottomhalf.filled"
      case .webtoon:
        return "arrow.up.and.down.square"
      }
    } else {
      switch self {
      case .ltr:
        return "rectangle.trailinghalf.inset.filled.arrow.trailing"
      case .rtl:
        return "rectangle.leadinghalf.inset.filled.arrow.leading"
      case .vertical:
        return "rectangle.portrait.bottomhalf.filled"
      case .webtoon:
        return "arrow.up.and.down.square"
      }
    }
  }
}

@MainActor
@Observable
class ReaderViewModel {
  var pages: [BookPage] = []
  var currentPage = 0
  var isLoading = false
  var errorMessage: String?
  var pageImageCache: ImageCache
  var readingDirection: ReadingDirection = .ltr

  private let bookService = BookService.shared
  var bookId: String = ""  // Internal for cache access

  init() {
    self.pageImageCache = ImageCache()
  }

  func loadPages(bookId: String, initialPage: Int? = nil) async {
    self.bookId = bookId
    isLoading = true
    errorMessage = nil

    // Clear memory cache when loading a new book (keep disk cache)
    pageImageCache.removeAll()

    do {
      pages = try await bookService.getBookPages(id: bookId)

      // Set initial page if provided (page number is 1-based)
      if let initialPage = initialPage {
        // Find the page index that matches the page number (1-based)
        if let pageIndex = pages.firstIndex(where: { $0.number == initialPage }) {
          currentPage = pageIndex
        }
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadPageImage(pageIndex: Int) async -> Image? {
    guard pageIndex >= 0 && pageIndex < pages.count else {
      return nil
    }

    guard !bookId.isEmpty else {
      return nil
    }

    // Try cache first (memory -> disk)
    if let cachedImage = await pageImageCache.getImage(forKey: pageIndex, bookId: bookId) {
      return cachedImage
    }

    // Not in cache, download from network
    do {
      // Use the page number from the API response (1-based)
      let apiPageNumber = pages[pageIndex].number
      let data = try await bookService.getBookPage(bookId: bookId, page: apiPageNumber)

      // Save to disk cache first (raw data)
      await pageImageCache.storeImageData(data, forKey: pageIndex, bookId: bookId)

      // Decode image
      if let uiImage = await pageImageCache.decodeImage(from: data) {
        let image = Image(uiImage: uiImage)
        // Store decoded image to memory cache
        pageImageCache.storeImage(image, forKey: pageIndex)
        return image
      }
    } catch {
      // Silently fail for image loading
    }

    return nil
  }

  // Legacy method for compatibility (returns UIImage for WebtoonReaderView)
  func loadPageImageUIImage(pageIndex: Int) async -> UIImage? {
    guard pageIndex >= 0 && pageIndex < pages.count else {
      return nil
    }

    guard !bookId.isEmpty else {
      return nil
    }

    // Try disk cache first
    if let data = await pageImageCache.getImageData(forKey: pageIndex, bookId: bookId) {
      return await pageImageCache.decodeImage(from: data)
    }

    // Not in cache, download from network
    do {
      let apiPageNumber = pages[pageIndex].number
      let data = try await bookService.getBookPage(bookId: bookId, page: apiPageNumber)

      // Save to disk cache
      await pageImageCache.storeImageData(data, forKey: pageIndex, bookId: bookId)

      // Decode and return
      return await pageImageCache.decodeImage(from: data)
    } catch {
      // Silently fail
    }

    return nil
  }

  func preloadPages() async {
    // Preload current page, previous pages, and next pages for smoother scrolling
    // Reduced preloading to save memory: 1 page before and 3 pages after
    let preloadBefore = max(0, currentPage - 1)
    let preloadAfter = min(currentPage + 3, pages.count)
    let pagesToPreload = Array(preloadBefore..<preloadAfter)

    // Load pages concurrently for better performance
    await withTaskGroup(of: Void.self) { group in
      for pageIndex in pagesToPreload {
        // Check if already in cache (memory or disk)
        if await pageImageCache.getImage(forKey: pageIndex, bookId: bookId) == nil {
          group.addTask {
            _ = await self.loadPageImage(pageIndex: pageIndex)
          }
        }
      }
    }

    // Clean up pages that are far from current page
    let keepRange = max(0, currentPage - 2)..<min(pages.count, currentPage + 5)
    pageImageCache.removePagesNotInRange(keepRange, keepCount: 2)
  }

  // Preload pages around a specific page index (for when pages appear in TabView)
  func preloadPagesAround(pageIndex: Int) async {
    // Reduced preloading: 1 page before and 3 pages after
    let preloadBefore = max(0, pageIndex - 1)
    let preloadAfter = min(pageIndex + 3, pages.count)
    let pagesToPreload = Array(preloadBefore..<preloadAfter)

    // Load pages concurrently for better performance
    await withTaskGroup(of: Void.self) { group in
      for index in pagesToPreload {
        // Check if already in cache (memory or disk)
        if await pageImageCache.getImage(forKey: index, bookId: bookId) == nil {
          group.addTask {
            _ = await self.loadPageImage(pageIndex: index)
          }
        }
      }
    }

    // Clean up pages that are far from this page
    let keepRange = max(0, pageIndex - 2)..<min(pages.count, pageIndex + 5)
    pageImageCache.removePagesNotInRange(keepRange, keepCount: 2)
  }

  func updateProgress() async {
    guard !bookId.isEmpty else { return }
    guard currentPage >= 0 && currentPage < pages.count else { return }

    let completed = currentPage >= pages.count - 1
    // Use the API page number (1-based) instead of array index (0-based)
    let apiPageNumber = pages[currentPage].number

    do {
      try await bookService.updateReadProgress(
        bookId: bookId,
        page: apiPageNumber,
        completed: completed
      )
    } catch {
      // Silently fail for progress updates
    }
  }

  // Convert display index to actual page index based on reading direction
  func displayIndexToPageIndex(_ displayIndex: Int) -> Int {
    switch readingDirection {
    case .ltr:
      return displayIndex
    case .rtl:
      return pages.count - 1 - displayIndex
    case .vertical, .webtoon:
      return displayIndex
    }
  }

  // Convert actual page index to display index based on reading direction
  func pageIndexToDisplayIndex(_ pageIndex: Int) -> Int {
    switch readingDirection {
    case .ltr:
      return pageIndex
    case .rtl:
      return pages.count - 1 - pageIndex
    case .vertical, .webtoon:
      return pageIndex
    }
  }
}
