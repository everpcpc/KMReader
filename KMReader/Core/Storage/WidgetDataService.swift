//
// WidgetDataService.swift
//
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
      guard await Self.canWriteWidgetData(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      let configuredWidgetKinds = await WidgetConfigurationService.shared.configuredWidgetKinds(
        matching: WidgetDataStore.widgetKinds
      )
      guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      Self.clearWidgetPayloads(
        forKinds: Set(WidgetDataStore.widgetKinds).subtracting(configuredWidgetKinds)
      )
      guard !configuredWidgetKinds.isEmpty else {
        Self.copyThumbnails(books: [], series: [], removingStaleFiles: true)
        return
      }

      var copiedBooks: [Book] = []
      var copiedSeries: [Series] = []
      var reloadedKinds: Set<String> = []
      var keepReadingCount = 0
      var recentlyAddedCount = 0
      var recentlyUpdatedSeriesCount = 0

      guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      if configuredWidgetKinds.contains(WidgetDataStore.keepReading.kind) {
        let books =
          (try? await DatabaseOperator.database().fetchKeepReadingBooksForWidget(
            instanceId: instanceId, libraryIds: libraryIds, limit: 6)) ?? []
        guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
          return
        }
        WidgetDataStore.saveEntries(
          books.map { Self.bookToEntry($0) },
          forKey: WidgetDataStore.keepReading.storageKey
        )
        copiedBooks += books
        reloadedKinds.insert(WidgetDataStore.keepReading.kind)
        keepReadingCount = books.count
      }

      if configuredWidgetKinds.contains(WidgetDataStore.recentlyAdded.kind) {
        let books =
          (try? await DatabaseOperator.database().fetchRecentlyAddedBooksForWidget(
            instanceId: instanceId, libraryIds: libraryIds, limit: 6)) ?? []
        guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
          return
        }
        WidgetDataStore.saveEntries(
          books.map { Self.bookToEntry($0) },
          forKey: WidgetDataStore.recentlyAdded.storageKey
        )
        copiedBooks += books
        reloadedKinds.insert(WidgetDataStore.recentlyAdded.kind)
        recentlyAddedCount = books.count
      }

      if configuredWidgetKinds.contains(WidgetDataStore.recentlyUpdatedSeries.kind) {
        let series =
          (try? await DatabaseOperator.database().fetchRecentlyUpdatedSeriesForWidget(
            instanceId: instanceId, libraryIds: libraryIds, limit: 6)) ?? []
        guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
          return
        }
        WidgetDataStore.saveSeriesEntries(
          series.map { Self.seriesToEntry($0) },
          forKey: WidgetDataStore.recentlyUpdatedSeries.storageKey
        )
        copiedSeries += series
        reloadedKinds.insert(WidgetDataStore.recentlyUpdatedSeries.kind)
        recentlyUpdatedSeriesCount = series.count
      }

      Self.copyThumbnails(
        books: copiedBooks,
        series: copiedSeries,
        removingStaleFiles: true
      )

      Self.reloadWidgets(kinds: reloadedKinds)
      AppLogger(.app).debug(
        "Widget data refreshed: keepReading=\(keepReadingCount), recentlyAdded=\(recentlyAddedCount), recentlyUpdatedSeries=\(recentlyUpdatedSeriesCount)"
      )
    }
  }

  static func updateKeepReadingBooks(_ books: [Book], instanceId: String, libraryIds: [String]) {
    let books = Array(books.prefix(6))
    Task.detached(priority: .utility) {
      guard await Self.canWriteWidgetData(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      guard
        await WidgetConfigurationService.shared.hasConfiguredWidget(
          kind: WidgetDataStore.keepReading.kind
        )
      else {
        WidgetDataStore.clearEntries(for: WidgetDataStore.keepReading)
        return
      }
      guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      WidgetDataStore.saveEntries(
        books.map { Self.bookToEntry($0) },
        forKey: WidgetDataStore.keepReading.storageKey
      )
      Self.copyThumbnails(books: books, series: [])
      Self.reloadWidget(kind: WidgetDataStore.keepReading.kind)
    }
  }

  static func updateRecentlyAddedBooks(_ books: [Book], instanceId: String, libraryIds: [String]) {
    let books = Array(books.prefix(6))
    Task.detached(priority: .utility) {
      guard await Self.canWriteWidgetData(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      guard
        await WidgetConfigurationService.shared.hasConfiguredWidget(
          kind: WidgetDataStore.recentlyAdded.kind
        )
      else {
        WidgetDataStore.clearEntries(for: WidgetDataStore.recentlyAdded)
        return
      }
      guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      WidgetDataStore.saveEntries(
        books.map { Self.bookToEntry($0) },
        forKey: WidgetDataStore.recentlyAdded.storageKey
      )
      Self.copyThumbnails(books: books, series: [])
      Self.reloadWidget(kind: WidgetDataStore.recentlyAdded.kind)
    }
  }

  static func updateRecentlyUpdatedSeries(
    _ series: [Series],
    instanceId: String,
    libraryIds: [String]
  ) {
    let series = Array(series.prefix(6))
    Task.detached(priority: .utility) {
      guard await Self.canWriteWidgetData(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      guard
        await WidgetConfigurationService.shared.hasConfiguredWidget(
          kind: WidgetDataStore.recentlyUpdatedSeries.kind
        )
      else {
        WidgetDataStore.clearEntries(for: WidgetDataStore.recentlyUpdatedSeries)
        return
      }
      guard Self.isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
        return
      }
      WidgetDataStore.saveSeriesEntries(
        series.map { Self.seriesToEntry($0) },
        forKey: WidgetDataStore.recentlyUpdatedSeries.storageKey
      )
      Self.copyThumbnails(books: [], series: series)
      Self.reloadWidget(kind: WidgetDataStore.recentlyUpdatedSeries.kind)
    }
  }

  static func updateKeepReadingBookIds(
    _ bookIds: [String],
    instanceId: String,
    libraryIds: [String]
  ) async {
    guard await canWriteWidgetData(instanceId: instanceId, libraryIds: libraryIds) else { return }
    let books =
      await DatabaseOperator.databaseIfConfigured()?.fetchBooksForWidget(
        bookIds: Array(bookIds.prefix(6)),
        instanceId: instanceId
      ) ?? []
    updateKeepReadingBooks(books, instanceId: instanceId, libraryIds: libraryIds)
  }

  static func updateRecentlyAddedBookIds(
    _ bookIds: [String],
    instanceId: String,
    libraryIds: [String]
  ) async {
    guard await canWriteWidgetData(instanceId: instanceId, libraryIds: libraryIds) else { return }
    let books =
      await DatabaseOperator.databaseIfConfigured()?.fetchBooksForWidget(
        bookIds: Array(bookIds.prefix(6)),
        instanceId: instanceId
      ) ?? []
    updateRecentlyAddedBooks(books, instanceId: instanceId, libraryIds: libraryIds)
  }

  static func updateRecentlyUpdatedSeriesIds(
    _ seriesIds: [String],
    instanceId: String,
    libraryIds: [String]
  ) async {
    guard await canWriteWidgetData(instanceId: instanceId, libraryIds: libraryIds) else { return }
    let series =
      await DatabaseOperator.databaseIfConfigured()?.fetchSeriesForWidget(
        seriesIds: Array(seriesIds.prefix(6)),
        instanceId: instanceId
      ) ?? []
    updateRecentlyUpdatedSeries(series, instanceId: instanceId, libraryIds: libraryIds)
  }

  @MainActor
  static func clearWidgetData() {
    WidgetDataStore.clearAll()
    #if canImport(WidgetKit)
      WidgetCenter.shared.reloadAllTimelines()
    #endif
    logger.debug("Widget data cleared")
  }

  private static nonisolated func bookToEntry(_ book: Book) -> WidgetBookEntry {
    let thumbnailFile = ThumbnailCache.getThumbnailFileURL(id: book.id, type: .book)
    let fileName =
      FileManager.default.fileExists(atPath: thumbnailFile.path)
      ? bookThumbnailFileName(bookId: book.id) : nil

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

  private static nonisolated func seriesToEntry(_ series: Series) -> WidgetSeriesEntry {
    let thumbnailFile = ThumbnailCache.getThumbnailFileURL(id: series.id, type: .series)
    let fileName =
      FileManager.default.fileExists(atPath: thumbnailFile.path)
      ? seriesThumbnailFileName(seriesId: series.id) : nil

    return WidgetSeriesEntry(
      id: series.id,
      title: series.metadata.title,
      booksCount: series.booksCount,
      unreadCount: series.booksUnreadCount + series.booksInProgressCount,
      lastModified: series.lastModified,
      thumbnailFileName: fileName
    )
  }

  private static nonisolated func copyThumbnails(
    books: [Book],
    series: [Series],
    removingStaleFiles: Bool = false
  ) {
    guard let destDir = WidgetDataStore.thumbnailDirectory else { return }
    let fm = FileManager.default

    if !fm.fileExists(atPath: destDir.path) {
      try? fm.createDirectory(at: destDir, withIntermediateDirectories: true)
    }

    if removingStaleFiles {
      let validFileNames = Set(
        books.compactMap { book -> String? in
          let source = ThumbnailCache.getThumbnailFileURL(id: book.id, type: .book)
          return fm.fileExists(atPath: source.path) ? bookThumbnailFileName(bookId: book.id) : nil
        }
          + series.compactMap { series in
            let source = ThumbnailCache.getThumbnailFileURL(id: series.id, type: .series)
            return fm.fileExists(atPath: source.path)
              ? seriesThumbnailFileName(seriesId: series.id) : nil
          }
      )

      if let existing = try? fm.contentsOfDirectory(atPath: destDir.path) {
        for file in existing where !validFileNames.contains(file) {
          try? fm.removeItem(at: destDir.appendingPathComponent(file))
        }
      }
    }

    for book in books {
      let source = ThumbnailCache.getThumbnailFileURL(id: book.id, type: .book)
      let dest = destDir.appendingPathComponent(bookThumbnailFileName(bookId: book.id))
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

    for series in series {
      let source = ThumbnailCache.getThumbnailFileURL(id: series.id, type: .series)
      let dest = destDir.appendingPathComponent(seriesThumbnailFileName(seriesId: series.id))
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

  private static nonisolated func bookThumbnailFileName(bookId: String) -> String {
    "book_\(bookId).jpg"
  }

  private static nonisolated func seriesThumbnailFileName(seriesId: String) -> String {
    "series_\(seriesId).jpg"
  }

  private static nonisolated func reloadWidget(kind: String) {
    #if canImport(WidgetKit)
      WidgetCenter.shared.reloadTimelines(ofKind: kind)
    #endif
  }

  private static nonisolated func reloadWidgets(kinds: Set<String>) {
    #if canImport(WidgetKit)
      for kind in kinds {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
      }
    #endif
  }

  private static nonisolated func clearWidgetPayloads(forKinds kinds: Set<String>) {
    guard !kinds.isEmpty else { return }
    for widget in WidgetDataStore.widgets where kinds.contains(widget.kind) {
      WidgetDataStore.clearEntries(for: widget)
    }
  }

  private static nonisolated func canWriteWidgetData(
    instanceId: String,
    libraryIds: [String]
  ) async -> Bool {
    guard isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds) else {
      return false
    }
    guard !(await isProtectedInstance(instanceId)) else {
      if AppConfig.current.instanceId == instanceId {
        await clearWidgetData()
      }
      return false
    }
    return isCurrentWidgetContext(instanceId: instanceId, libraryIds: libraryIds)
  }

  private static nonisolated func isCurrentWidgetContext(
    instanceId: String,
    libraryIds: [String]
  ) -> Bool {
    guard !instanceId.isEmpty, AppConfig.current.instanceId == instanceId else { return false }
    return Set(AppConfig.dashboard.libraryIds) == Set(libraryIds)
  }

  private static nonisolated func isProtectedInstance(_ instanceId: String) async -> Bool {
    guard !instanceId.isEmpty else { return false }
    do {
      let database = try await DatabaseOperator.database()
      return try await database.isServerProtected(instanceId: instanceId)
    } catch {
      AppLogger(.app).error(
        "Failed to check protected server state for widget data: \(error.localizedDescription)"
      )
      return true
    }
  }
}
