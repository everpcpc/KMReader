//
//  SpotlightIndexService.swift
//  KMReader
//

@preconcurrency import CoreSpotlight
import Foundation

#if os(iOS) || os(macOS)
  enum SpotlightIndexService: Sendable {
    private static nonisolated let domainIdentifier = "com.everpcpc.Komga.books"

    static nonisolated func indexBook(_ book: Book) {
      let attributeSet = makeAttributeSet(for: book)
      let bookId = book.id
      let title = book.metadata.title
      let item = CSSearchableItem(
        uniqueIdentifier: bookId,
        domainIdentifier: domainIdentifier,
        attributeSet: attributeSet
      )

      CSSearchableIndex.default().indexSearchableItems([item]) { error in
        if let error {
          AppLogger(.app).error(
            "Failed to index book \(bookId): \(error.localizedDescription)")
        } else {
          AppLogger(.app).debug("Indexed book for Spotlight: \(title)")
        }
      }
    }

    static nonisolated func removeBook(bookId: String) {
      CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [bookId]) { error in
        if let error {
          AppLogger(.app).error(
            "Failed to remove book \(bookId) from Spotlight: \(error.localizedDescription)")
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
      let domain = domainIdentifier
      Task.detached(priority: .utility) {
        let books = await DatabaseOperator.shared.fetchDownloadedBooks(instanceId: instanceId)
        guard !books.isEmpty else { return }

        let items = books.map { book -> CSSearchableItem in
          let attributeSet = makeAttributeSet(for: book)
          return CSSearchableItem(
            uniqueIdentifier: book.id,
            domainIdentifier: domain,
            attributeSet: attributeSet
          )
        }

        let count = items.count
        CSSearchableIndex.default().indexSearchableItems(items) { error in
          if let error {
            AppLogger(.app).error(
              "Failed to batch index \(count) books: \(error.localizedDescription)")
          } else {
            AppLogger(.app).info("Spotlight indexed \(count) downloaded books")
          }
        }
      }
    }

    private static nonisolated func makeAttributeSet(for book: Book)
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
  }
#endif
