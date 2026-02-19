//
// SpotlightIndexService.swift
//
//

@preconcurrency import CoreSpotlight
import Foundation

#if os(iOS) || os(macOS)
  enum SpotlightIndexService: Sendable {
    private static nonisolated let domainIdentifier = "com.everpcpc.Komga.books"
    private static nonisolated let bookPrefix = "book:"
    private static nonisolated let seriesPrefix = "series:"

    static nonisolated func deepLink(for searchableItemIdentifier: String) -> DeepLink? {
      guard let identifier = normalizedIdentifier(from: searchableItemIdentifier) else {
        return nil
      }

      if identifier.hasPrefix(bookPrefix) {
        let payload = String(identifier.dropFirst(bookPrefix.count))
        guard !payload.isEmpty else { return nil }
        return .book(bookId: extractItemId(from: payload))
      }

      if identifier.hasPrefix(seriesPrefix) {
        let payload = String(identifier.dropFirst(seriesPrefix.count))
        guard !payload.isEmpty else { return nil }
        return .series(seriesId: extractItemId(from: payload))
      }

      return .book(bookId: identifier)
    }

    static nonisolated func indexBook(_ book: Book, instanceId: String) {
      guard AppConfig.enableSpotlightIndexing else { return }
      guard shouldIndex(libraryId: book.libraryId, instanceId: instanceId) else {
        removeBook(bookId: book.id, instanceId: instanceId)
        if AppConfig.enableSpotlightSeriesIndexing {
          indexSeries(
            seriesId: book.seriesId,
            seriesTitle: book.seriesTitle,
            instanceId: instanceId
          )
        }
        return
      }

      if AppConfig.enableSpotlightBookIndexing {
        let attributeSet = makeBookAttributeSet(for: book)
        let bookId = book.id
        let title = book.metadata.title
        let item = CSSearchableItem(
          uniqueIdentifier: bookIdentifier(bookId: bookId, instanceId: instanceId),
          domainIdentifier: domainIdentifier,
          attributeSet: attributeSet
        )

        Task.detached(priority: .utility) {
          do {
            try await CSSearchableIndex.default().indexSearchableItems([item])
            AppLogger(.app).debug("Indexed book for Spotlight: \(title)")
          } catch {
            AppLogger(.app).error(
              "Failed to index book \(bookId): \(error.localizedDescription)")
          }
        }
      } else {
        removeBook(bookId: book.id, instanceId: instanceId)
      }

      if AppConfig.enableSpotlightSeriesIndexing {
        indexSeries(
          seriesId: book.seriesId,
          seriesTitle: book.seriesTitle,
          instanceId: instanceId
        )
      } else {
        removeSeries(seriesId: book.seriesId, instanceId: instanceId)
      }
    }

    static nonisolated func removeBook(bookId: String, instanceId: String) {
      let identifier = bookIdentifier(bookId: bookId, instanceId: instanceId)
      CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
        if let error {
          AppLogger(.app).error(
            "Failed to remove book \(identifier) from Spotlight: \(error.localizedDescription)")
        }
      }
    }

    static nonisolated func removeSeries(seriesId: String, instanceId: String) {
      let identifier = seriesIdentifier(seriesId: seriesId, instanceId: instanceId)
      CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { error in
        if let error {
          AppLogger(.app).error(
            "Failed to remove series \(identifier) from Spotlight: \(error.localizedDescription)")
        }
      }
    }

    static nonisolated func removeAllItems() {
      let domain = domainIdentifier
      CSSearchableIndex.default().deleteSearchableItems(
        withDomainIdentifiers: [domain]
      ) { error in
        if let error {
          AppLogger(.app).error(
            "Failed to remove all Spotlight items: \(error.localizedDescription)")
        }
      }
    }

    static nonisolated func indexAllDownloadedBooks(instanceId: String) {
      guard AppConfig.enableSpotlightIndexing else { return }
      let domain = domainIdentifier
      Task.detached(priority: .utility) {
        let books = await DatabaseOperator.shared.fetchDownloadedBooks(instanceId: instanceId)
        let filteredBooks = filterBooksForIndexedLibraries(books, instanceId: instanceId)
        var items: [CSSearchableItem] = []

        if AppConfig.enableSpotlightBookIndexing {
          let bookItems = filteredBooks.map { book -> CSSearchableItem in
            let attributeSet = makeBookAttributeSet(for: book)
            return CSSearchableItem(
              uniqueIdentifier: bookIdentifier(bookId: book.id, instanceId: instanceId),
              domainIdentifier: domain,
              attributeSet: attributeSet
            )
          }
          items.append(contentsOf: bookItems)
        }

        if AppConfig.enableSpotlightSeriesIndexing {
          let seriesItems = makeSeriesItems(from: filteredBooks, domain: domain, instanceId: instanceId)
          items.append(contentsOf: seriesItems)
        }

        guard !items.isEmpty else { return }
        let count = items.count
        do {
          try await CSSearchableIndex.default().indexSearchableItems(items)
          AppLogger(.app).info("Spotlight indexed \(count) items")
        } catch {
          AppLogger(.app).error(
            "Failed to batch index \(count) items: \(error.localizedDescription)")
        }
      }
    }

    private static nonisolated func indexSeries(
      seriesId: String,
      seriesTitle: String,
      instanceId: String
    ) {
      let item = CSSearchableItem(
        uniqueIdentifier: seriesIdentifier(seriesId: seriesId, instanceId: instanceId),
        domainIdentifier: domainIdentifier,
        attributeSet: makeSeriesAttributeSet(
          seriesId: seriesId,
          seriesTitle: seriesTitle
        )
      )
      Task.detached(priority: .utility) {
        do {
          try await CSSearchableIndex.default().indexSearchableItems([item])
        } catch {
          AppLogger(.app).error("Failed to index series \(seriesId): \(error.localizedDescription)")
        }
      }
    }

    private static nonisolated func shouldIndex(libraryId: String, instanceId: String) -> Bool {
      guard let selectedLibraryIds = AppConfig.spotlightIndexedLibraryIds(instanceId: instanceId)
      else {
        return true
      }
      return selectedLibraryIds.contains(libraryId)
    }

    private static nonisolated func filterBooksForIndexedLibraries(
      _ books: [Book],
      instanceId: String
    ) -> [Book] {
      guard let selectedLibraryIds = AppConfig.spotlightIndexedLibraryIds(instanceId: instanceId)
      else {
        return books
      }
      guard !selectedLibraryIds.isEmpty else { return [] }
      let selected = Set(selectedLibraryIds)
      return books.filter { selected.contains($0.libraryId) }
    }

    private static nonisolated func makeBookAttributeSet(for book: Book)
      -> CSSearchableItemAttributeSet
    {
      let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
      attributeSet.title = book.metadata.title
      attributeSet.contentDescription = "\(book.seriesTitle) - #\(book.metadata.number)"
      if let authors = book.metadata.authors {
        attributeSet.authorNames = authors.map(\.name)
      }
      attributeSet.keywords = [book.seriesTitle, book.metadata.title, "comic", "manga"]

      let thumbnailURL = ThumbnailCache.getThumbnailFileURL(id: book.id, type: .book)
      if FileManager.default.fileExists(atPath: thumbnailURL.path) {
        attributeSet.thumbnailURL = thumbnailURL
      }

      return attributeSet
    }

    private static nonisolated func makeSeriesAttributeSet(
      seriesId: String,
      seriesTitle: String
    )
      -> CSSearchableItemAttributeSet
    {
      let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
      attributeSet.title = seriesTitle
      attributeSet.contentDescription = "Series"
      attributeSet.keywords = [seriesTitle, "series", "comic", "manga"]

      let seriesThumbnailURL = ThumbnailCache.getThumbnailFileURL(id: seriesId, type: .series)
      if FileManager.default.fileExists(atPath: seriesThumbnailURL.path) {
        attributeSet.thumbnailURL = seriesThumbnailURL
      }

      return attributeSet
    }

    private static nonisolated func makeSeriesItems(
      from books: [Book],
      domain: String,
      instanceId: String
    ) -> [CSSearchableItem] {
      var seriesMap: [String: String] = [:]
      for book in books {
        if seriesMap[book.seriesId] == nil {
          seriesMap[book.seriesId] = book.seriesTitle
        }
      }

      return seriesMap.map { seriesId, seriesTitle in
        CSSearchableItem(
          uniqueIdentifier: seriesIdentifier(seriesId: seriesId, instanceId: instanceId),
          domainIdentifier: domain,
          attributeSet: makeSeriesAttributeSet(
            seriesId: seriesId,
            seriesTitle: seriesTitle
          )
        )
      }
    }

    private static nonisolated func normalizedIdentifier(from identifier: String) -> String? {
      let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { return nil }
      return trimmed
    }

    private static nonisolated func extractItemId(from payload: String) -> String {
      guard let separator = payload.firstIndex(of: "_") else {
        return payload
      }

      let itemStart = payload.index(after: separator)
      let itemId = String(payload[itemStart...])
      return itemId.isEmpty ? payload : itemId
    }

    private static nonisolated func bookIdentifier(bookId: String, instanceId: String) -> String {
      "\(bookPrefix)\(CompositeID.generate(instanceId: instanceId, id: bookId))"
    }

    private static nonisolated func seriesIdentifier(seriesId: String, instanceId: String) -> String {
      "\(seriesPrefix)\(CompositeID.generate(instanceId: instanceId, id: seriesId))"
    }
  }
#endif
