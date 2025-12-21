//
//  DatabaseOperator.swift
//  KMReader
//
//  Created by Komga iOS Client
//

import Foundation
import OSLog
import SwiftData

@ModelActor
actor DatabaseOperator {
  static var shared: DatabaseOperator!

  private let logger = AppLogger(.database)

  func commit() throws {
    try modelContext.save()
  }

  // MARK: - Book Operations

  func upsertBook(dto: Book, instanceId: String) {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaBook>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      existing.name = dto.name
      existing.url = dto.url
      existing.number = dto.number
      existing.lastModified = dto.lastModified
      existing.sizeBytes = dto.sizeBytes
      existing.size = dto.size
      existing.media = dto.media
      existing.metadata = dto.metadata
      existing.readProgress = dto.readProgress
      existing.deleted = dto.deleted
      existing.oneshot = dto.oneshot
      existing.seriesTitle = dto.seriesTitle
    } else {
      let newBook = KomgaBook(
        bookId: dto.id,
        seriesId: dto.seriesId,
        libraryId: dto.libraryId,
        instanceId: instanceId,
        name: dto.name,
        url: dto.url,
        number: dto.number,
        created: dto.created,
        lastModified: dto.lastModified,
        sizeBytes: dto.sizeBytes,
        size: dto.size,
        media: dto.media,
        metadata: dto.metadata,
        readProgress: dto.readProgress,
        deleted: dto.deleted,
        oneshot: dto.oneshot,
        seriesTitle: dto.seriesTitle
      )
      modelContext.insert(newBook)
    }
  }

  func upsertBooks(_ books: [Book], instanceId: String) {
    for book in books {
      upsertBook(dto: book, instanceId: instanceId)
    }
  }

  // MARK: - Series Operations

  func upsertSeries(dto: Series, instanceId: String) {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaSeries>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      existing.name = dto.name
      existing.url = dto.url
      existing.lastModified = dto.lastModified
      existing.booksCount = dto.booksCount
      existing.booksReadCount = dto.booksReadCount
      existing.booksUnreadCount = dto.booksUnreadCount
      existing.booksInProgressCount = dto.booksInProgressCount
      existing.metadata = dto.metadata
      existing.booksMetadata = dto.booksMetadata
      existing.deleted = dto.deleted
      existing.oneshot = dto.oneshot
    } else {
      let newSeries = KomgaSeries(
        seriesId: dto.id,
        libraryId: dto.libraryId,
        instanceId: instanceId,
        name: dto.name,
        url: dto.url,
        created: dto.created,
        lastModified: dto.lastModified,
        booksCount: dto.booksCount,
        booksReadCount: dto.booksReadCount,
        booksUnreadCount: dto.booksUnreadCount,
        booksInProgressCount: dto.booksInProgressCount,
        metadata: dto.metadata,
        booksMetadata: dto.booksMetadata,
        deleted: dto.deleted,
        oneshot: dto.oneshot
      )
      modelContext.insert(newSeries)
    }
  }

  func upsertSeriesList(_ seriesList: [Series], instanceId: String) {
    for series in seriesList {
      upsertSeries(dto: series, instanceId: instanceId)
    }
  }

  // MARK: - Collection Operations

  func upsertCollection(dto: SeriesCollection, instanceId: String) {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaCollection>(
      predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      existing.name = dto.name
      existing.ordered = dto.ordered
      existing.filtered = dto.filtered
      existing.lastModifiedDate = dto.lastModifiedDate
      existing.seriesIds = dto.seriesIds
    } else {
      let newCollection = KomgaCollection(
        collectionId: dto.id,
        instanceId: instanceId,
        name: dto.name,
        ordered: dto.ordered,
        createdDate: dto.createdDate,
        lastModifiedDate: dto.lastModifiedDate,
        filtered: dto.filtered,
        seriesIds: dto.seriesIds
      )
      modelContext.insert(newCollection)
    }
  }

  func upsertCollections(_ collections: [SeriesCollection], instanceId: String) {
    for col in collections {
      upsertCollection(dto: col, instanceId: instanceId)
    }
  }

  // MARK: - ReadList Operations

  func upsertReadList(dto: ReadList, instanceId: String) {
    let compositeId = "\(instanceId)_\(dto.id)"
    let descriptor = FetchDescriptor<KomgaReadList>(predicate: #Predicate { $0.id == compositeId })
    if let existing = try? modelContext.fetch(descriptor).first {
      existing.name = dto.name
      existing.summary = dto.summary
      existing.ordered = dto.ordered
      existing.filtered = dto.filtered
      existing.lastModifiedDate = dto.lastModifiedDate
      existing.bookIds = dto.bookIds
    } else {
      let newReadList = KomgaReadList(
        readListId: dto.id,
        instanceId: instanceId,
        name: dto.name,
        summary: dto.summary,
        ordered: dto.ordered,
        createdDate: dto.createdDate,
        lastModifiedDate: dto.lastModifiedDate,
        filtered: dto.filtered,
        bookIds: dto.bookIds
      )
      modelContext.insert(newReadList)
    }
  }

  func upsertReadLists(_ readLists: [ReadList], instanceId: String) {
    for rl in readLists {
      upsertReadList(dto: rl, instanceId: instanceId)
    }
  }

  // MARK: - Cleanup

  func clearInstanceData(instanceId: String) {
    do {
      try modelContext.delete(
        model: KomgaBook.self, where: #Predicate { $0.instanceId == instanceId })
      try modelContext.delete(
        model: KomgaSeries.self, where: #Predicate { $0.instanceId == instanceId })
      try modelContext.delete(
        model: KomgaCollection.self, where: #Predicate { $0.instanceId == instanceId })
      try modelContext.delete(
        model: KomgaReadList.self, where: #Predicate { $0.instanceId == instanceId })

      try commit()
      logger.info("🗑️ Cleared all SwiftData entities for instance: \(instanceId)")
    } catch {
      logger.error("❌ Failed to clear instance data: \(error)")
    }
  }
}
