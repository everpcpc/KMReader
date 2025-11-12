//
//  ReaderViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import UIKit

enum ReadingDirection {
  case ltr  // Left to Right (从左往右)
  case rtl  // Right to Left (从右往左)
}

@MainActor
@Observable
class ReaderViewModel {
  var pages: [BookPage] = []
  var currentPage = 0
  var isLoading = false
  var errorMessage: String?
  var pageImageCache: [Int: UIImage] = [:]
  var readingDirection: ReadingDirection = .ltr

  private let bookService = BookService.shared
  private var bookId: String = ""

  func loadPages(bookId: String, initialPage: Int? = nil) async {
    self.bookId = bookId
    isLoading = true
    errorMessage = nil

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

  func loadPageImage(pageIndex: Int) async -> UIImage? {
    if let cached = pageImageCache[pageIndex] {
      return cached
    }

    guard pageIndex >= 0 && pageIndex < pages.count else {
      return nil
    }

    do {
      // Use the page number from the API response (1-based)
      let apiPageNumber = pages[pageIndex].number
      let data = try await bookService.getBookPage(bookId: bookId, page: apiPageNumber)
      if let image = UIImage(data: data) {
        pageImageCache[pageIndex] = image
        return image
      }
    } catch {
      // Silently fail for individual pages
    }

    return nil
  }

  func preloadPages() async {
    // Preload current page and next few pages
    let pagesToPreload = Array(currentPage..<min(currentPage + 3, pages.count))

    for pageIndex in pagesToPreload {
      if pageImageCache[pageIndex] == nil {
        _ = await loadPageImage(pageIndex: pageIndex)
      }
    }
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
    }
  }

  // Convert actual page index to display index based on reading direction
  func pageIndexToDisplayIndex(_ pageIndex: Int) -> Int {
    switch readingDirection {
    case .ltr:
      return pageIndex
    case .rtl:
      return pages.count - 1 - pageIndex
    }
  }
}
