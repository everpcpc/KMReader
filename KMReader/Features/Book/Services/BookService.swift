//
// BookService.swift
//
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
  private let progressRequestTimeout: TimeInterval = 1

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

  func fetchRemoteWebPubProgression(bookId: String) async -> RemoteEpubProgressionFetchResult {
    let requestPath = "/api/v1/books/\(bookId)/progression"

    do {
      let response = try await apiClient.requestData(
        path: requestPath,
        headers: ["Accept": "application/vnd.readium.progression+json"]
      )
      return decodeRemoteWebPubProgression(bookId: bookId, path: requestPath, data: response.data)
    } catch let apiError as APIError {
      if apiError.statusCode == 404 {
        logger.debug("⏭️ [Progress/Epub] Remote progression missing (404): book=\(bookId)")
        return .missing
      }

      if isRetryableProgressionError(apiError) {
        return .retryableFailure(apiError)
      }

      logger.warning(
        "⏭️ [Progress/Epub] Non-retryable remote progression response: book=\(bookId), status=\(apiError.statusCode ?? -1)"
      )
      return .invalidPayload(apiError)
    } catch {
      return .retryableFailure(error)
    }
  }

  func getWebPubProgression(bookId: String) async throws -> R2Progression? {
    switch await fetchRemoteWebPubProgression(bookId: bookId) {
    case .available(let progression):
      return progression
    case .missing:
      return nil
    case .retryableFailure(let error), .invalidPayload(let error):
      throw error
    }
  }

  func getWebPubPositions(bookId: String) async throws -> R2Positions {
    return try await apiClient.request(path: "/api/v1/books/\(bookId)/positions")
  }

  private func decodeRemoteWebPubProgression(
    bookId: String,
    path: String,
    data: Data
  ) -> RemoteEpubProgressionFetchResult {
    guard !data.isEmpty else {
      logger.debug("⏭️ [Progress/Epub] Remote progression missing (empty body): book=\(bookId)")
      return .missing
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    do {
      let progression = try decoder.decode(R2Progression.self, from: data)
      if isEmptyProgressionLocator(progression.locator) {
        logger.debug("⏭️ [Progress/Epub] Remote progression missing (empty locator): book=\(bookId)")
        return .missing
      }
      return .available(progression)
    } catch {
      if hasEmptyProgressionLocatorPayload(data) {
        logger.debug("⏭️ [Progress/Epub] Remote progression missing (empty raw locator): book=\(bookId)")
        return .missing
      }

      let responseBody = String(data: data, encoding: .utf8)
      return .invalidPayload(
        APIError.decodingError(
          error,
          url: AppConfig.current.serverURL + path,
          response: responseBody
        )
      )
    }
  }

  private func isEmptyProgressionLocator(_ locator: R2Locator) -> Bool {
    locator.href.isEmpty
      && locator.type.isEmpty
      && locator.title == nil
      && locator.locations == nil
      && locator.text == nil
      && locator.koboSpan == nil
  }

  private func hasEmptyProgressionLocatorPayload(_ data: Data) -> Bool {
    guard
      let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let locator = jsonObject["locator"] as? [String: Any]
    else {
      return false
    }

    return locator.isEmpty
  }

  private func isRetryableProgressionError(_ error: APIError) -> Bool {
    switch error {
    case .networkError, .offline, .tooManyRequests, .serverError:
      return true
    default:
      return false
    }
  }

  func updateWebPubProgression(
    bookId: String,
    progression: R2Progression,
    timeout: TimeInterval? = nil
  ) async throws {
    logger.debug(
      "📡 [Progress/Epub] Request start: book=\(bookId), href=\(progression.locator.href), progression=\(progression.locator.locations?.progression ?? 0), totalProgression=\(progression.locator.locations?.totalProgression ?? 0), timeout=\(timeout ?? progressRequestTimeout)s"
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(progression)
    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/progression",
      method: "PUT",
      body: data,
      timeout: timeout ?? progressRequestTimeout,
      maxRetryCount: 0
    )
    logger.debug("✅ [Progress/Epub] Request completed: book=\(bookId)")
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
    sort: String? = nil,
    unpaged: Bool = false
  ) async throws -> Page<Book> {
    var queryItems: [URLQueryItem] = []

    if unpaged {
      queryItems.append(URLQueryItem(name: "unpaged", value: "true"))
    } else {
      queryItems.append(URLQueryItem(name: "page", value: "\(page)"))
      queryItems.append(URLQueryItem(name: "size", value: "\(size)"))
    }

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

  func updatePageReadProgress(
    bookId: String,
    page: Int,
    completed: Bool = false,
    timeout: TimeInterval? = nil
  ) async throws {
    logger.debug(
      "📡 [Progress/Page] Request start: book=\(bookId), page=\(page), completed=\(completed), timeout=\(timeout ?? progressRequestTimeout)s"
    )
    let body = ["page": page, "completed": completed] as [String: Any]
    let jsonData = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

    let _: EmptyResponse = try await apiClient.request(
      path: "/api/v1/books/\(bookId)/read-progress",
      method: "PATCH",
      body: jsonData,
      timeout: timeout ?? progressRequestTimeout,
      maxRetryCount: 0
    )
    logger.debug("✅ [Progress/Page] Request completed: book=\(bookId), page=\(page)")
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
    } catch APIError.notFound {
      return nil
    }
  }

  func getPreviousBook(bookId: String, readListId: String? = nil) async throws -> Book? {
    do {
      if let readListId = readListId {
        return try await apiClient.request(
          path: "/api/v1/readlists/\(readListId)/books/\(bookId)/previous"
        )
      } else {
        return try await apiClient.request(path: "/api/v1/books/\(bookId)/previous")
      }
    } catch APIError.notFound {
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
