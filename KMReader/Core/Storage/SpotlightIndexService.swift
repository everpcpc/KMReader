//
//  SpotlightIndexService.swift
//  KMReader
//

@preconcurrency import CoreSpotlight
import Foundation

#if os(iOS) || os(macOS)
  enum SpotlightIndexService: Sendable {
    private static nonisolated let domainIdentifier = "com.everpcpc.Komga.books"
    private static nonisolated let bookPrefix = "book:"
    private static nonisolated let seriesPrefix = "series:"

    static nonisolated func indexBook(_ book: Book, instanceId: String) {
      guard AppConfig.enableSpotlightIndexing else { return }
      guard shouldIndex(libraryId: book.libraryId, instanceId: instanceId) else {
        removeBook(bookId: book.id, instanceId: instanceId)
        if AppConfig.enableSpotlightSeriesIndexing {
          indexSeries(seriesId: book.seriesId, seriesTitle: book.seriesTitle, instanceId: instanceId)
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
        indexSeries(seriesId: book.seriesId, seriesTitle: book.seriesTitle, instanceId: instanceId)
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
        attributeSet: makeSeriesAttributeSet(seriesTitle: seriesTitle)
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

    private static nonisolated func makeSeriesAttributeSet(seriesTitle: String)
      -> CSSearchableItemAttributeSet
    {
      let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
      attributeSet.title = seriesTitle
      attributeSet.contentDescription = "Series"
      attributeSet.keywords = [seriesTitle, "series", "comic", "manga"]
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
          attributeSet: makeSeriesAttributeSet(seriesTitle: seriesTitle)
        )
      }
    }

    private static nonisolated func bookIdentifier(bookId: String, instanceId: String) -> String {
      "\(bookPrefix)\(CompositeID.generate(instanceId: instanceId, id: bookId))"
    }

    private static nonisolated func seriesIdentifier(seriesId: String, instanceId: String) -> String {
      "\(seriesPrefix)\(CompositeID.generate(instanceId: instanceId, id: seriesId))"
    }
  }
#endif
