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

  // MARK: - Book Download Status Operations

  func updateBookDownloadStatus(
    bookId: String,
    instanceId: String,
    status: DownloadStatus,
    downloadAt: Date? = nil,
    downloadedSize: Int64? = nil
  ) {
    let compositeId = "\(instanceId)_\(bookId)"
    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    guard let book = try? modelContext.fetch(descriptor).first else { return }
    book.downloadStatus = status
    if let downloadAt = downloadAt {
      book.downloadAt = downloadAt
    }
    if let downloadedSize = downloadedSize {
      book.downloadedSize = downloadedSize
    } else if case .notDownloaded = status {
      book.downloadedSize = 0
    }

    try? modelContext.save()

    // Sync series status
    let seriesId = book.seriesId
    let compositeSeriesId = "\(instanceId)_\(seriesId)"
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeSeriesId }
    )
    if let series = try? modelContext.fetch(seriesDescriptor).first {
      syncSeriesDownloadStatus(series: series)
      try? modelContext.save()
    }
  }

  func syncSeriesDownloadStatus(series: KomgaSeries) {
    let seriesId = series.seriesId
    let instanceId = series.instanceId

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []

    let totalCount = series.booksCount
    let downloadedCount = books.filter { $0.downloadStatusRaw == "downloaded" }.count
    let pendingCount = books.filter { $0.downloadStatusRaw == "pending" }.count

    series.downloadedBooks = downloadedCount
    series.pendingBooks = pendingCount
    series.downloadedSize = books.reduce(0) { $0 + $1.downloadedSize }
    series.downloadAt = books.compactMap { $0.downloadAt }.max()

    if downloadedCount == totalCount {
      series.downloadStatusRaw = "downloaded"
    } else if pendingCount > 0 {
      series.downloadStatusRaw = "pending"
    } else {
      series.downloadStatusRaw = "notDownloaded"
    }

    handlePolicyActions(series: series, books: books)
  }

  func syncSeriesDownloadStatus(seriesId: String, instanceId: String) {
    let compositeId = "\(instanceId)_\(seriesId)"
    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(descriptor).first else { return }
    syncSeriesDownloadStatus(series: series)
    try? modelContext.save()
  }

  private func handlePolicyActions(series: KomgaSeries, books: [KomgaBook]) {
    let policy = series.offlinePolicy
    guard policy != .manual else { return }

    var needsSyncQueue = false
    var booksToDelete: [KomgaBook] = []

    for book in books {
      let isRead = book.progressCompleted ?? false
      let isDownloaded = book.downloadStatusRaw == "downloaded"
      let isPending = book.downloadStatusRaw == "pending"
      let isFailed = book.downloadStatusRaw == "failed"

      let shouldBeOffline: Bool
      switch policy {
      case .manual:
        shouldBeOffline = (isDownloaded || isPending)
      case .unreadOnly, .unreadOnlyAndCleanupRead:
        shouldBeOffline = !isRead
      case .all:
        shouldBeOffline = true
      }

      if shouldBeOffline {
        if !isDownloaded && !isPending && !isFailed {
          book.downloadStatusRaw = "pending"
          book.downloadAt = .now
          needsSyncQueue = true
        }
      } else {
        if (isDownloaded || isPending) && policy == .unreadOnlyAndCleanupRead {
          booksToDelete.append(book)
        }
      }
    }

    if needsSyncQueue {
      OfflineManager.shared.triggerSync(instanceId: series.instanceId)
    }

    if !booksToDelete.isEmpty {
      let instanceId = series.instanceId
      Task {
        for book in booksToDelete {
          await OfflineManager.shared.deleteBook(instanceId: instanceId, bookId: book.bookId)
        }
      }
    }
  }

  func downloadAllBooks(seriesId: String, instanceId: String) {
    let compositeId = "\(instanceId)_\(seriesId)"
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue
    try? modelContext.save()

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []
    for book in books {
      if book.downloadStatusRaw != "downloaded" && book.downloadStatusRaw != "pending" {
        book.downloadStatusRaw = "pending"
        book.downloadAt = Date.now
      }
    }

    OfflineManager.shared.triggerSync(instanceId: instanceId)
    syncSeriesDownloadStatus(series: series)
    try? modelContext.save()
  }

  func removeAllBooks(seriesId: String, instanceId: String) {
    let compositeId = "\(instanceId)_\(seriesId)"
    let seriesDescriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

    series.offlinePolicyRaw = SeriesOfflinePolicy.manual.rawValue
    try? modelContext.save()

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.seriesId == seriesId && $0.instanceId == instanceId }
    )
    let books = (try? modelContext.fetch(descriptor)) ?? []
    for book in books {
      book.downloadStatusRaw = "notDownloaded"
      book.downloadError = nil
      book.downloadAt = nil
      book.downloadedSize = 0
    }
    try? modelContext.save()

    Task {
      for book in books {
        await OfflineManager.shared.deleteBook(instanceId: instanceId, bookId: book.bookId)
      }
    }

    syncSeriesDownloadStatus(series: series)
    try? modelContext.save()
  }

  func toggleSeriesDownload(seriesId: String, instanceId: String) {
    let compositeId = "\(instanceId)_\(seriesId)"
    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(descriptor).first else { return }

    let status = series.downloadStatus
    switch status {
    case .downloaded, .partiallyDownloaded, .pending:
      removeAllBooks(seriesId: seriesId, instanceId: instanceId)
    case .notDownloaded:
      downloadAllBooks(seriesId: seriesId, instanceId: instanceId)
    }
  }

  func updateSeriesOfflinePolicy(seriesId: String, instanceId: String, policy: SeriesOfflinePolicy) {
    let compositeId = "\(instanceId)_\(seriesId)"
    let descriptor = FetchDescriptor<KomgaSeries>(
      predicate: #Predicate { $0.id == compositeId }
    )
    guard let series = try? modelContext.fetch(descriptor).first else { return }

    series.offlinePolicy = policy
    try? modelContext.save()

    syncSeriesDownloadStatus(series: series)
    try? modelContext.save()
  }

  // MARK: - Library Operations

  func replaceLibraries(_ libraries: [LibraryInfo], for instanceId: String) throws {
    let descriptor = FetchDescriptor<KomgaLibrary>(
      predicate: #Predicate { $0.instanceId == instanceId }
    )
    let existing = try modelContext.fetch(descriptor)

    var existingMap = Dictionary(
      uniqueKeysWithValues: existing.map { ($0.libraryId, $0) }
    )
    var didChange = false

    for library in libraries {
      if let existingLibrary = existingMap[library.id] {
        if existingLibrary.name != library.name {
          existingLibrary.name = library.name
          didChange = true
        }
        existingMap.removeValue(forKey: library.id)
      } else {
        modelContext.insert(
          KomgaLibrary(
            instanceId: instanceId,
            libraryId: library.id,
            name: library.name
          ))
        didChange = true
      }
    }

    let allLibrariesId = KomgaLibrary.allLibrariesId
    for (_, library) in existingMap {
      if library.libraryId != allLibrariesId {
        modelContext.delete(library)
        didChange = true
      }
    }

    if didChange {
      try modelContext.save()
    }
  }

  func deleteLibraries(instanceId: String?) throws {
    let descriptor: FetchDescriptor<KomgaLibrary>
    if let instanceId {
      descriptor = FetchDescriptor(
        predicate: #Predicate { $0.instanceId == instanceId }
      )
    } else {
      descriptor = FetchDescriptor()
    }
    let items = try modelContext.fetch(descriptor)
    items.forEach { modelContext.delete($0) }
    try modelContext.save()
  }

  func upsertAllLibrariesEntry(
    instanceId: String,
    fileSize: Double?,
    booksCount: Double?,
    seriesCount: Double?,
    sidecarsCount: Double?,
    collectionsCount: Double?,
    readlistsCount: Double?
  ) throws {
    let allLibrariesId = KomgaLibrary.allLibrariesId
    let descriptor = FetchDescriptor<KomgaLibrary>(
      predicate: #Predicate { library in
        library.instanceId == instanceId && library.libraryId == allLibrariesId
      }
    )

    if let existing = try modelContext.fetch(descriptor).first {
      existing.fileSize = fileSize
      existing.booksCount = booksCount
      existing.seriesCount = seriesCount
      existing.sidecarsCount = sidecarsCount
      existing.collectionsCount = collectionsCount
      existing.readlistsCount = readlistsCount
    } else {
      let allLibrariesEntry = KomgaLibrary(
        instanceId: instanceId,
        libraryId: KomgaLibrary.allLibrariesId,
        name: "All Libraries",
        fileSize: fileSize,
        booksCount: booksCount,
        seriesCount: seriesCount,
        sidecarsCount: sidecarsCount,
        collectionsCount: collectionsCount,
        readlistsCount: readlistsCount
      )
      modelContext.insert(allLibrariesEntry)
    }

    try modelContext.save()
  }

  // MARK: - Instance Operations

  @discardableResult
  func upsertInstance(
    serverURL: String,
    username: String,
    authToken: String,
    isAdmin: Bool,
    authMethod: AuthenticationMethod = .basicAuth,
    displayName: String? = nil
  ) throws -> KomgaInstance {
    let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.serverURL == serverURL && instance.username == username
      })

    if let existing = try modelContext.fetch(descriptor).first {
      existing.authToken = authToken
      existing.isAdmin = isAdmin
      existing.authMethod = authMethod
      existing.lastUsedAt = Date()
      if let trimmedDisplayName, !trimmedDisplayName.isEmpty {
        existing.name = trimmedDisplayName
      } else if existing.name.isEmpty {
        existing.name = Self.defaultName(serverURL: serverURL, username: username)
      }
      try modelContext.save()
      return existing
    } else {
      let resolvedName = Self.resolvedName(
        displayName: trimmedDisplayName, serverURL: serverURL, username: username)
      let instance = KomgaInstance(
        name: resolvedName,
        serverURL: serverURL,
        username: username,
        authToken: authToken,
        isAdmin: isAdmin,
        authMethod: authMethod
      )
      modelContext.insert(instance)
      try modelContext.save()
      return instance
    }
  }

  private static func defaultName(serverURL: String, username: String) -> String {
    if let host = URL(string: serverURL)?.host, !host.isEmpty {
      return host
    }
    return serverURL
  }

  private static func resolvedName(
    displayName: String?, serverURL: String, username: String
  ) -> String {
    if let displayName, !displayName.isEmpty {
      return displayName
    }
    return defaultName(serverURL: serverURL, username: username)
  }

  func updateInstanceLastUsed(instanceId: String) {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try? modelContext.fetch(descriptor).first {
      instance.lastUsedAt = Date()
      try? modelContext.save()
    }
  }

  func updateSeriesLastSyncedAt(instanceId: String, date: Date) throws {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try modelContext.fetch(descriptor).first {
      instance.seriesLastSyncedAt = date
      try modelContext.save()
    }
  }

  func updateBooksLastSyncedAt(instanceId: String, date: Date) throws {
    guard let uuid = UUID(uuidString: instanceId) else { return }
    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })
    if let instance = try modelContext.fetch(descriptor).first {
      instance.booksLastSyncedAt = date
      try modelContext.save()
    }
  }

  // MARK: - Fetch Operations

  func fetchInstance(idString: String?) -> KomgaInstance? {
    guard
      let idString,
      let uuid = UUID(uuidString: idString)
    else {
      return nil
    }

    let descriptor = FetchDescriptor<KomgaInstance>(
      predicate: #Predicate { instance in
        instance.id == uuid
      })

    return try? modelContext.fetch(descriptor).first
  }

  func getLastSyncedAt(instanceId: String) -> (series: Date, books: Date) {
    guard let instance = fetchInstance(idString: instanceId) else {
      return (Date(timeIntervalSince1970: 0), Date(timeIntervalSince1970: 0))
    }
    return (instance.seriesLastSyncedAt, instance.booksLastSyncedAt)
  }

  func fetchLibraries(instanceId: String) -> [LibraryInfo] {
    let descriptor = FetchDescriptor<KomgaLibrary>(
      predicate: #Predicate { $0.instanceId == instanceId },
      sortBy: [SortDescriptor(\KomgaLibrary.name, order: .forward)]
    )
    guard let libraries = try? modelContext.fetch(descriptor) else { return [] }
    return libraries.map { LibraryInfo(id: $0.libraryId, name: $0.name) }
  }

  // MARK: - Book Fetch Operations (for internal use, e.g., OfflineManager)

  func getDownloadStatus(bookId: String) -> DownloadStatus {
    let instanceId = AppConfig.currentInstanceId
    let compositeId = "\(instanceId)_\(bookId)"

    let descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.id == compositeId }
    )

    guard let book = try? modelContext.fetch(descriptor).first else { return .notDownloaded }
    return book.downloadStatus
  }

  func fetchPendingBooks(limit: Int? = nil) -> [Book] {
    let instanceId = AppConfig.currentInstanceId

    var descriptor = FetchDescriptor<KomgaBook>(
      predicate: #Predicate { $0.instanceId == instanceId && $0.downloadStatusRaw == "pending" },
      sortBy: [SortDescriptor(\KomgaBook.downloadAt, order: .forward)]
    )

    if let limit = limit {
      descriptor.fetchLimit = limit
    }

    do {
      let results = try modelContext.fetch(descriptor)
      return results.map { $0.toBook() }
    } catch {
      return []
    }
  }
}
