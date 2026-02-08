//
//  BookService.swift
//  Komga
//
//  Created by Komga iOS Client
//

import Foundation

struct BookFileDownloadResult {
  let data: Data
  let contentType: String?
  let suggestedFilename: String?
}

class BookService {
  static let shared = BookService()
  private let apiClient = APIClient.shared
  private let logger = AppLogger(.api)

  private init() {}

  func getBooks(
    seriesId: String,
    page: Int = 0,
    size: Int = 500,
    browseOpts: BookBrowseOptions,
    libraryIds: [String]? = nil
  ) async throws -> Page<Book> {
    let sort = browseOpts.sortString
    let filters = BookSearchFilters(
      libraryIds: libraryIds,
      includeReadStatuses: Array(browseOpts.includeReadStatuses),
      excludeReadStatuses: Array(browseOpts.excludeReadStatuses),
      oneshot: browseOpts.oneshotFilter.effectiveBool,
      deleted: browseOpts.deletedFilter.effectiveBool,
      seriesId: seriesId,
      readListId: nil,
      authors: browseOpts.metadataFilter.authors,
      authorsLogic: browseOpts.metadataFilter.authorsLogic,
      tags: browseOpts.metadataFilter.tags,
      tagsLogic: browseOpts.metadataFilter.tagsLogic
    )
    let condition = BookSearch.buildCondition(filters: filters)
    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )
  }

  func getBook(id: String) async throws -> Book {
    return try await apiClient.request(path: "/api/v1/books/\(id)")
  }

  func getReadListsForBook(bookId: String) async throws -> [ReadList] {
    return try await apiClient.request(path: "/api/v1/books/\(bookId)/readlists")
  }

  func getBookPages(id: String) async throws -> [BookPage] {
    return try await apiClient.request(path: "/api/v1/books/\(id)/pages")
  }

  func getBookManifest(id: String) async throws -> DivinaManifest {
    return try await apiClient.request(
      path: "/api/v1/books/\(id)/manifest",
      headers: ["Accept": "application/divina+json"]
    )
  }

  func getBookWebPubManifest(bookId: String) async throws -> WebPubPublication {
    return try await apiClient.request(
      path: "/api/v1/books/\(bookId)/manifest",
      headers: ["Accept": "application/webpub+json"]
    )
  }

  func getWebPubProgression(bookId: String) async throws -> R2Progression? {
    return try await apiClient.requestOptional(path: "/api/v1/books/\(bookId)/progression")
  }

  func getWebPubPositions(bookId: String) async throws -> R2Positions {
    return try await apiClient.request(path: "/api/v1/books/\(bookId)/positions")
  }

  func updateWebPubProgression(bookId: String, progression: R2Progression) async throws {
    logger.debug(
      "📤 Sending EPUB progression for book \(bookId): href=\(progression.locator.href), progression=\(progression.locator.locations?.progression ?? 0), totalProgression=\(progression.locator.locations?.totalProgression ?? 0)"
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(progression)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/progression",
      method: "PUT",
      body: data
    )
    logger.debug("✅ EPUB progression sent for book \(bookId)")
  }

  func downloadBookFile(bookId: String) async throws -> BookFileDownloadResult {
    let result = try await apiClient.requestDataWithProgress(
      path: "/api/v1/books/\(bookId)/file",
      progressKey: bookId,
    )
    return BookFileDownloadResult(
      data: result.data,
      contentType: result.contentType,
      suggestedFilename: result.suggestedFilename
    )
  }

  func getBrowseBooks(
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20,
    browseOpts: BookBrowseOptions,
    searchTerm: String? = nil
  ) async throws -> Page<Book> {
    let sort = browseOpts.sortString
    let filters = BookSearchFilters(
      libraryIds: libraryIds,
      includeReadStatuses: Array(browseOpts.includeReadStatuses),
      excludeReadStatuses: Array(browseOpts.excludeReadStatuses),
      oneshot: browseOpts.oneshotFilter.effectiveBool,
      deleted: browseOpts.deletedFilter.effectiveBool,
      authors: browseOpts.metadataFilter.authors,
      authorsLogic: browseOpts.metadataFilter.authorsLogic,
      tags: browseOpts.metadataFilter.tags,
      tagsLogic: browseOpts.metadataFilter.tagsLogic
    )
    let condition = BookSearch.buildCondition(filters: filters)
    let search = BookSearch(
      condition: condition,
      fullTextSearch: searchTerm?.isEmpty == false ? searchTerm : nil
    )

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: sort
    )
  }

  func getBooksList(
    search: BookSearch,
    page: Int = 0,
    size: Int = 20,
    sort: String? = nil
  ) async throws -> Page<Book> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    if let sort = sort {
      queryItems.append(URLQueryItem(name: "sort", value: sort))
    }

    let encoder = JSONEncoder()
    let jsonData = try encoder.encode(search)

    return try await apiClient.request(
      path: "/api/v1/books/list",
      method: "POST",
      body: jsonData,
      queryItems: queryItems
    )
  }

  func getBooksOnDeck(
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    var queryItems = [
      URLQueryItem(name: "page", value: "\(page)"),
      URLQueryItem(name: "size", value: "\(size)"),
    ]

    // Support multiple libraryIds
    if let libraryIds = libraryIds, !libraryIds.isEmpty {
      for id in libraryIds where !id.isEmpty {
        queryItems.append(URLQueryItem(name: "library_id", value: id))
      }
    }

    return try await apiClient.request(path: "/api/v1/books/ondeck", queryItems: queryItems)
  }

  /// Get thumbnail URL for a book
  func getBookThumbnailURL(id: String) -> URL? {
    let baseURL = AppConfig.current.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/books/\(id)/thumbnail")
  }

  /// Get page thumbnail URL for a book
  func getBookPageThumbnailURL(bookId: String, page: Int) -> URL? {
    let baseURL = AppConfig.current.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/books/\(bookId)/pages/\(page)/thumbnail")
  }

  /// Get direct page image URL for a book page
  func getBookPageURL(bookId: String, page: Int) -> URL? {
    let baseURL = AppConfig.current.serverURL
    guard !baseURL.isEmpty else { return nil }
    return URL(string: baseURL + "/api/v1/books/\(bookId)/pages/\(page)")
  }

  func getBookPage(bookId: String, page: Int) async throws -> (data: Data, contentType: String?) {
    let result = try await apiClient.requestData(path: "/api/v1/books/\(bookId)/pages/\(page)")
    return (data: result.data, contentType: result.contentType)
  }

  func downloadResource(at url: URL) async throws -> (data: Data, contentType: String?) {
    let result = try await apiClient.requestData(url: url)
    return (data: result.data, contentType: result.contentType)
  }

  func downloadImageResource(at url: URL) async throws -> (data: Data, contentType: String?) {
    let result = try await apiClient.requestData(
      url: url,
      headers: ["Accept": "image/*"]
    )
    return (data: result.data, contentType: result.contentType)
  }

  func updatePageReadProgress(bookId: String, page: Int, completed: Bool = false) async throws {
    logger.debug(
      "📤 Sending page progress for book \(bookId): page=\(page), completed=\(completed)"
    )
    let body = ["page": page, "completed": completed] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "PATCH",
      body: jsonData
    )
    logger.debug("✅ Page progress sent for book \(bookId): page=\(page)")
  }

  func deleteReadProgress(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "DELETE"
    )
  }

  func getNextBook(bookId: String, readListId: String? = nil) async throws -> Book? {
    do {
      if let readListId = readListId {
        // Use readlist-specific endpoint when readListId is provided
        return try await apiClient.request(
          path: "/api/v1/readlists/\(readListId)/books/\(bookId)/next"
        )
      } else {
        // Use series endpoint when no readListId
        return try await apiClient.request(
          path: "/api/v1/books/\(bookId)/next"
        )
      }
    } catch {
      return nil
    }
  }

  func getPreviousBook(bookId: String) async throws -> Book? {
    do {
      return try await apiClient.request(path: "/api/v1/books/\(bookId)/previous")
    } catch {
      return nil
    }
  }

  func analyzeBook(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/analyze",
      method: "POST"
    )
  }

  func refreshMetadata(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/metadata/refresh",
      method: "POST"
    )
  }

  func deleteBook(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/file",
      method: "DELETE"
    )
  }

  func markAsRead(bookId: String) async throws {
    // Fetch the book to get the total page count
    let book = try await getBook(id: bookId)
    let lastPage = book.media.pagesCount

    // Use PATCH with completed: true and the last page number
    let body = ["page": lastPage, "completed": true] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "PATCH",
      body: jsonData
    )
  }

  func markAsUnread(bookId: String) async throws {
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "DELETE"
    )
  }

  func getRecentlyReadBooks(
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    // Get books with READ status, sorted by last read date
    let condition = BookSearch.buildCondition(
      filters: BookSearchFilters(
        libraryIds: libraryIds,
        includeReadStatuses: [.read]
      )
    )

    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: "readProgress.readDate,desc"
    )
  }

  func getRecentlyAddedBooks(
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    // Get books sorted by created date (most recent first)
    // Empty condition means match all books
    let condition = BookSearch.buildCondition(
      filters: BookSearchFilters(libraryIds: libraryIds)
    )

    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: "createdDate,desc"
    )
  }

  func getRecentlyReleasedBooks(
    libraryIds: [String]? = nil,
    page: Int = 0,
    size: Int = 20
  ) async throws -> Page<Book> {
    // Get books sorted by release date (most recent first)
    // Only include books that have a release date
    let condition = BookSearch.buildCondition(
      filters: BookSearchFilters(libraryIds: libraryIds)
    )

    let search = BookSearch(condition: condition)

    return try await getBooksList(
      search: search,
      page: page,
      size: size,
      sort: "metadata.releaseDate,desc"
    )
  }

  func updateBookMetadata(bookId: String, metadata: [String: Any]) async throws {
    let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/metadata",
      method: "PATCH",
      body: jsonData
    )
  }
}
