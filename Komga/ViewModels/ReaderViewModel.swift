//
//  ReaderViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import UIKit

@MainActor
@Observable
class ReaderViewModel {
  var pages: [BookPage] = []
  var currentPage = 0
  var isLoading = false
  var errorMessage: String?
  var pageImageCache: [Int: UIImage] = [:]

  private let bookService = BookService.shared
  private var bookId: String = ""

  func loadPages(bookId: String) async {
    self.bookId = bookId
    isLoading = true
    errorMessage = nil

    do {
      pages = try await bookService.getBookPages(id: bookId)
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

    let completed = currentPage >= pages.count - 1

    do {
      try await bookService.updateReadProgress(
        bookId: bookId,
        page: currentPage,
        completed: completed
      )
    } catch {
      // Silently fail for progress updates
    }
  }
}
