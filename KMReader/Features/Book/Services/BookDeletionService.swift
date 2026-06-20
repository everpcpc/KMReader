//
// BookDeletionService.swift
//
//

import Foundation

nonisolated enum BookDeletionService {
  static func deleteBook(_ item: BookDisplayItem) async throws {
    try await deleteBook(
      bookId: item.bookId,
      instanceId: item.instanceId,
      seriesId: item.seriesId,
      libraryId: item.book.libraryId
    )
  }

  static func deleteBook(
    _ book: Book,
    instanceId: String = AppConfig.current.instanceId
  ) async throws {
    try await deleteBook(
      bookId: book.id,
      instanceId: instanceId,
      seriesId: book.seriesId,
      libraryId: book.libraryId
    )
  }

  static func deleteBook(
    bookId: String,
    instanceId: String = AppConfig.current.instanceId,
    seriesId: String? = nil,
    libraryId: String? = nil
  ) async throws {
    let scope = await resolveScope(
      bookId: bookId,
      instanceId: instanceId,
      seriesId: seriesId,
      libraryId: libraryId
    )

    try await BookService.deleteBook(bookId: bookId)

    await markBookUnavailable(bookId: bookId, instanceId: instanceId)
    await CacheManager.clearCache(forBookId: bookId)
    await ContentProjectionNotifier.postBookAndSeriesDidChange(
      bookId: bookId,
      instanceId: instanceId,
      seriesId: scope.seriesId,
      libraryId: scope.libraryId
    )
  }

  private static func markBookUnavailable(bookId: String, instanceId: String) async {
    guard let database = try? await DatabaseOperator.database() else { return }
    await database.markBookUnavailable(bookId: bookId, instanceId: instanceId)
  }

  private static func resolveScope(
    bookId: String,
    instanceId: String,
    seriesId: String?,
    libraryId: String?
  ) async -> (seriesId: String?, libraryId: String?) {
    if seriesId != nil, libraryId != nil {
      return (seriesId, libraryId)
    }

    guard
      let database = try? await DatabaseOperator.database(),
      let item = try? await database.fetchBookDisplayItem(bookId: bookId, instanceId: instanceId)
    else {
      return (seriesId, libraryId)
    }

    return (
      seriesId ?? item.seriesId,
      libraryId ?? item.book.libraryId
    )
  }
}
