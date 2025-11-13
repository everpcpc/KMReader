//
//  BookViewModel.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation
import UIKit

@MainActor
@Observable
class BookViewModel {
  var books: [Book] = []
  var currentBook: Book?
  var isLoading = false
  var errorMessage: String?
  var thumbnailCache: [String: UIImage] = [:]

  private let bookService = BookService.shared

  func loadBooks(seriesId: String) async {
    isLoading = true
    errorMessage = nil

    do {
      let page = try await bookService.getBooks(seriesId: seriesId)
      books = page.content
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadBook(id: String) async {
    isLoading = true
    errorMessage = nil

    do {
      currentBook = try await bookService.getBook(id: id)
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadBooksOnDeck(libraryId: String? = nil) async {
    isLoading = true
    errorMessage = nil

    do {
      let page = try await bookService.getBooksOnDeck(libraryId: libraryId, size: 20)
      books = page.content
    } catch {
      errorMessage = error.localizedDescription
    }

    isLoading = false
  }

  func loadThumbnail(for bookId: String) async -> UIImage? {
    if let cached = thumbnailCache[bookId] {
      return cached
    }

    do {
      let data = try await bookService.getBookThumbnail(id: bookId)
      if let image = UIImage(data: data) {
        thumbnailCache[bookId] = image
        return image
      }
    } catch {
      // Silently fail for thumbnails
    }

    return nil
  }

  func updateReadProgress(bookId: String, page: Int, completed: Bool = false) async {
    do {
      try await bookService.updateReadProgress(bookId: bookId, page: page, completed: completed)
      // Reload the book to get updated progress
      if currentBook?.id == bookId {
        await loadBook(id: bookId)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func markAsRead(bookId: String) async {
    do {
      try await bookService.markAsRead(bookId: bookId)
      // Update the book in the list
      if books.firstIndex(where: { $0.id == bookId }) != nil {
        await loadBook(id: bookId)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func markAsUnread(bookId: String) async {
    do {
      try await bookService.markAsUnread(bookId: bookId)
      // Update the book in the list
      if books.firstIndex(where: { $0.id == bookId }) != nil {
        await loadBook(id: bookId)
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
