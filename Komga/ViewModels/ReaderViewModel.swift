//
//  ReaderViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import UIKit

enum ReadingDirection: CaseIterable, Hashable {
  case ltr  // Left to Right (从左往右)
  case rtl  // Right to Left (从右往左)
  case vertical  // Vertical (纵向翻页)
  case webtoon  // Webtoon (纵向连续滚动)

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
    switch self {
    case .ltr:
      return "arrow.right"
    case .rtl:
      return "arrow.left"
    case .vertical:
      return "arrow.down"
    case .webtoon:
      return "list.bullet"
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

    guard !bookId.isEmpty else {
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
      // Silently fail for image loading
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
