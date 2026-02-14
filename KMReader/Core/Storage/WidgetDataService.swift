//
//  WidgetDataService.swift
//  KMReader
//

import Foundation

#if canImport(WidgetKit)
  import WidgetKit
#endif

enum WidgetDataService {
  private static let logger = AppLogger(.app)

  @MainActor
  static func refreshWidgetData() {
    let instanceId = AppConfig.current.instanceId
    guard !instanceId.isEmpty else { return }
    let libraryIds = AppConfig.dashboard.libraryIds

    Task.detached(priority: .utility) {
      let keepReadingBooks = await DatabaseOperator.shared.fetchKeepReadingBooksForWidget(
        instanceId: instanceId, libraryIds: libraryIds, limit: 6)
      let recentlyAddedBooks = await DatabaseOperator.shared.fetchRecentlyAddedBooksForWidget(
        instanceId: instanceId, libraryIds: libraryIds, limit: 6)

      let keepReadingEntries = keepReadingBooks.map { Self.bookToEntry($0) }
      let recentlyAddedEntries = recentlyAddedBooks.map { Self.bookToEntry($0) }

      WidgetDataStore.saveEntries(keepReadingEntries, forKey: WidgetDataStore.keepReadingKey)
      WidgetDataStore.saveEntries(recentlyAddedEntries, forKey: WidgetDataStore.recentlyAddedKey)

      Self.copyThumbnails(for: keepReadingBooks + recentlyAddedBooks)

      #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
      #endif
      AppLogger(.app).debug(
        "Widget data refreshed: keepReading=\(keepReadingEntries.count), recentlyAdded=\(recentlyAddedEntries.count)"
      )
    }
  }

  private static nonisolated func bookToEntry(_ book: Book) -> WidgetBookEntry {
    let thumbnailFile = ThumbnailCache.getThumbnailFileURL(id: book.id, type: .book)
    let fileName =
      FileManager.default.fileExists(atPath: thumbnailFile.path)
      ? "\(book.id).jpg" : nil

    return WidgetBookEntry(
      id: book.id,
      seriesId: book.seriesId,
      title: book.metadata.title,
      seriesTitle: book.seriesTitle,
      number: book.number,
      progressPage: book.readProgress?.page,
      totalPages: book.media.pagesCount,
      progressCompleted: book.readProgress?.completed ?? false,
      thumbnailFileName: fileName,
      createdDate: book.created
    )
  }

  private static nonisolated func copyThumbnails(for books: [Book]) {
    guard let destDir = WidgetDataStore.thumbnailDirectory else { return }
    let fm = FileManager.default

    if !fm.fileExists(atPath: destDir.path) {
      try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
    }

    let validFileNames = Set(
      books.compactMap { book -> String? in
        let source = ThumbnailCache.getThumbnailFileURL(id: book.id, type: .book)
        return fm.fileExists(atPath: source.path) ? "\(book.id).jpg" : nil
      })

    if let existing = try? fm.contentsOfDirectory(atPath: destDir.path) {
      for file in existing where !validFileNames.contains(file) {
        try? fm.removeItem(at: destDir.appendingPathComponent(file))
      }
    }

    for book in books {
      let source = ThumbnailCache.getThumbnailFileURL(id: book.id, type: .book)
      let dest = destDir.appendingPathComponent("\(book.id).jpg")
      guard fm.fileExists(atPath: source.path) else { continue }

      if fm.fileExists(atPath: dest.path) {
        let srcDate =
          (try? fm.attributesOfItem(atPath: source.path)[.modificationDate] as? Date)
          ?? .distantPast
        let dstDate =
          (try? fm.attributesOfItem(atPath: dest.path)[.modificationDate] as? Date)
          ?? .distantPast
        if srcDate <= dstDate { continue }
        try? fm.removeItem(at: dest)
      }

      try? fm.copyItem(at: source, to: dest)
    }
  }
}
