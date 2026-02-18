#if os(iOS) || os(macOS)
  import Foundation
  import Observation
  import PDFKit

  enum PdfLoadingStage: String {
    case idle
    case fetchingMetadata
    case downloading
    case preparingReader
  }

  @MainActor
  @Observable
  class PdfReaderViewModel {
    var isLoading: Bool = false
    var errorMessage: String?
    var loadingStage: PdfLoadingStage = .idle

    var downloadProgress: Double = 0.0
    var downloadBytesReceived: Int64 = 0
    var downloadBytesExpected: Int64?

    var documentURL: URL?
    var initialPageNumber: Int = 1
    var currentPageNumber: Int = 1
    var pageCount: Int = 0
    var isSearching: Bool = false
    var searchResults: [PdfSearchResult] = []
    var tableOfContents: [ReaderTOCEntry] = []

    private let incognito: Bool
    private let logger = AppLogger(.reader)

    private var bookId: String = ""
    private var downloadInfo: DownloadInfo?

    init(incognito: Bool) {
      self.incognito = incognito
    }

    func beginLoading() {
      isLoading = true
      errorMessage = nil
      loadingStage = .fetchingMetadata
      downloadProgress = 0.0
      downloadBytesReceived = 0
      downloadBytesExpected = nil
      documentURL = nil
      pageCount = 0
      isSearching = false
      searchResults = []
      tableOfContents = []
    }

    func updateDownloadProgress(notification: Notification) {
      guard let progressKey = notification.userInfo?[DownloadProgressUserInfo.itemKey] as? String else {
        return
      }
      guard progressKey == bookId else { return }

      let expected = notification.userInfo?[DownloadProgressUserInfo.expectedKey] as? Int64
      let received = notification.userInfo?[DownloadProgressUserInfo.receivedKey] as? Int64 ?? 0

      downloadBytesReceived = received
      downloadBytesExpected = expected
      if let expected, expected > 0 {
        downloadProgress = min(1.0, Double(received) / Double(expected))
      }
    }

    func load(book: Book) async {
      beginLoading()
      bookId = book.id
      downloadInfo = book.downloadInfo
      initialPageNumber = max(1, book.readProgress?.page ?? 1)
      currentPageNumber = initialPageNumber

      do {
        guard let downloadInfo else {
          throw AppErrorType.missingRequiredData(
            message: "Missing book metadata for offline download."
          )
        }
        guard case .pdf = downloadInfo.kind else {
          throw AppErrorType.operationFailed(
            message: "This book is not a PDF file."
          )
        }

        let instanceId = AppConfig.current.instanceId
        try await ensureOfflineReady(downloadInfo: downloadInfo, instanceId: instanceId)

        var offlineURL = await OfflineManager.shared.getOfflinePDFURL(
          instanceId: instanceId,
          bookId: book.id
        )
        if offlineURL == nil && !AppConfig.isOffline {
          await OfflineManager.shared.retryDownload(instanceId: instanceId, bookId: book.id)
          try await ensureOfflineReady(downloadInfo: downloadInfo, instanceId: instanceId)
          offlineURL = await OfflineManager.shared.getOfflinePDFURL(
            instanceId: instanceId,
            bookId: book.id
          )
        }

        guard let offlineURL else {
          throw AppErrorType.missingRequiredData(
            message: "Offline PDF file is missing. Please re-download this book."
          )
        }

        loadingStage = .preparingReader
        guard let document = PDFDocument(url: offlineURL) else {
          throw AppErrorType.operationFailed(
            message: "Unable to open downloaded PDF file."
          )
        }

        documentURL = offlineURL
        pageCount = max(0, document.pageCount)
        if pageCount > 0 {
          let clamped = max(1, min(initialPageNumber, pageCount))
          initialPageNumber = clamped
          currentPageNumber = clamped
        } else {
          initialPageNumber = 1
          currentPageNumber = 1
        }
        tableOfContents = buildTableOfContents(from: document)
        downloadProgress = 1.0
        loadingStage = .idle
        isLoading = false
      } catch is CancellationError {
        logger.debug("PDF load cancelled for book \(book.id)")
        loadingStage = .idle
        isLoading = false
      } catch {
        errorMessage = error.localizedDescription
        ErrorManager.shared.alert(error: error)
        loadingStage = .idle
        isLoading = false
        logger.error("PDF load failed for book \(book.id): \(error.localizedDescription)")
      }
    }

    func updateCurrentPage(pageNumber: Int, totalPages: Int) {
      let normalizedTotal = max(0, totalPages)
      let normalizedPage = max(1, pageNumber)

      // PDFKit may emit duplicate page-changed callbacks during mode switches.
      // Ignore no-op updates to avoid feedback loops in SwiftUI view updates.
      if pageCount == normalizedTotal, currentPageNumber == normalizedPage {
        return
      }

      pageCount = normalizedTotal
      currentPageNumber = normalizedPage

      guard !bookId.isEmpty else { return }
      guard normalizedTotal > 0 else { return }
      guard !incognito else {
        logger.debug("⏭️ Skip PDF progress update because incognito mode is enabled")
        return
      }

      let completed = currentPageNumber >= normalizedTotal
      let snapshotPage = currentPageNumber
      let snapshotBookId = bookId

      Task {
        await ReaderProgressDispatchService.shared.submitPageProgress(
          bookId: snapshotBookId,
          page: snapshotPage,
          completed: completed
        )
      }
    }

    func flushProgress() {
      guard !bookId.isEmpty else { return }
      guard !incognito else {
        logger.debug("⏭️ Skip PDF progress flush because incognito mode is enabled")
        return
      }

      let snapshotPage = currentPageNumber > 0 ? currentPageNumber : nil
      let snapshotCompleted: Bool? = {
        guard let snapshotPage, pageCount > 0 else { return nil }
        return snapshotPage >= pageCount
      }()
      let snapshotBookId = bookId

      Task {
        await ReaderProgressDispatchService.shared.flushPageProgress(
          bookId: snapshotBookId,
          snapshotPage: snapshotPage,
          snapshotCompleted: snapshotCompleted
        )
      }
    }

    func search(text: String) async {
      let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
      if query.isEmpty {
        searchResults = []
        isSearching = false
        return
      }

      guard let documentURL else {
        searchResults = []
        isSearching = false
        return
      }

      isSearching = true
      searchResults = []

      guard let document = PDFDocument(url: documentURL) else {
        isSearching = false
        return
      }

      var results: [PdfSearchResult] = []
      let pageCount = document.pageCount

      for index in 0..<pageCount {
        guard let page = document.page(at: index), let text = page.string else {
          if index.isMultiple(of: 10) {
            await Task.yield()
          }
          continue
        }

        guard
          let matchRange = text.range(
            of: query,
            options: [.caseInsensitive, .diacriticInsensitive]
          )
        else {
          if index.isMultiple(of: 10) {
            await Task.yield()
          }
          continue
        }

        let snippet = buildSnippet(from: text, matchRange: matchRange)
        let pageNumber = index + 1
        results.append(
          PdfSearchResult(
            id: "\(pageNumber)-\(results.count)",
            pageNumber: pageNumber,
            snippet: snippet
          )
        )

        if results.count >= 200 {
          break
        }

        if index.isMultiple(of: 10) {
          await Task.yield()
        }
      }

      searchResults = results
      isSearching = false
    }

    private func ensureOfflineReady(downloadInfo: DownloadInfo, instanceId: String) async throws {
      let status = await OfflineManager.shared.getDownloadStatus(bookId: downloadInfo.bookId)
      if case .downloaded = status {
        downloadProgress = 1.0
        return
      }

      if AppConfig.isOffline {
        throw AppErrorType.networkUnavailable
      }

      loadingStage = .downloading
      downloadProgress = 0.0
      downloadBytesReceived = 0
      downloadBytesExpected = nil

      switch status {
      case .notDownloaded:
        await OfflineManager.shared.toggleDownload(instanceId: instanceId, info: downloadInfo)
      case .failed:
        await OfflineManager.shared.retryDownload(instanceId: instanceId, bookId: bookId)
      case .pending:
        break
      case .downloaded:
        downloadProgress = 1.0
        return
      }

      while true {
        if AppConfig.isOffline {
          throw AppErrorType.networkUnavailable
        }

        let currentStatus = await OfflineManager.shared.getDownloadStatus(bookId: bookId)
        switch currentStatus {
        case .downloaded:
          downloadProgress = 1.0
          return
        case .failed(let error):
          throw AppErrorType.operationFailed(message: error)
        case .notDownloaded:
          throw AppErrorType.operationFailed(
            message: "Download did not start. Please try again."
          )
        case .pending:
          if let progress = DownloadProgressTracker.shared.progress[bookId] {
            downloadProgress = progress
          }
        }

        try await Task.sleep(for: .milliseconds(200))
      }
    }

    private func buildSnippet(from text: String, matchRange: Range<String.Index>) -> String {
      let lowerBound =
        text.index(matchRange.lowerBound, offsetBy: -40, limitedBy: text.startIndex)
        ?? text.startIndex
      let upperBound =
        text.index(matchRange.upperBound, offsetBy: 80, limitedBy: text.endIndex)
        ?? text.endIndex

      var snippet = String(text[lowerBound..<upperBound])
      snippet = snippet.replacingOccurrences(
        of: #"\s+"#,
        with: " ",
        options: .regularExpression
      )
      snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)

      let hasLeadingEllipsis = lowerBound > text.startIndex
      let hasTrailingEllipsis = upperBound < text.endIndex

      if hasLeadingEllipsis {
        snippet = "..." + snippet
      }
      if hasTrailingEllipsis {
        snippet += "..."
      }

      return snippet
    }

    private func buildTableOfContents(from document: PDFDocument) -> [ReaderTOCEntry] {
      guard let outlineRoot = document.outlineRoot else { return [] }

      var entries: [ReaderTOCEntry] = []
      for index in 0..<outlineRoot.numberOfChildren {
        guard let child = outlineRoot.child(at: index),
          let entry = buildTOCEntry(from: child, in: document)
        else {
          continue
        }
        entries.append(entry)
      }
      return entries
    }

    private func buildTOCEntry(from outline: PDFOutline, in document: PDFDocument) -> ReaderTOCEntry? {
      var childEntries: [ReaderTOCEntry] = []
      for index in 0..<outline.numberOfChildren {
        guard let child = outline.child(at: index),
          let childEntry = buildTOCEntry(from: child, in: document)
        else {
          continue
        }
        childEntries.append(childEntry)
      }

      let ownPageIndex = pageIndex(from: outline, in: document)
      let fallbackPageIndex = childEntries.first?.pageIndex
      guard let pageIndex = ownPageIndex ?? fallbackPageIndex else { return nil }

      let trimmedLabel = outline.label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      let title = trimmedLabel.isEmpty ? localizedPageLabel(pageIndex + 1) : trimmedLabel
      return ReaderTOCEntry(
        title: title,
        pageIndex: pageIndex,
        children: childEntries.isEmpty ? nil : childEntries
      )
    }

    private func pageIndex(from outline: PDFOutline, in document: PDFDocument) -> Int? {
      if let destination = outline.destination,
        let page = destination.page
      {
        let index = document.index(for: page)
        guard index != NSNotFound, index >= 0, index < document.pageCount else {
          return nil
        }
        return index
      }

      if let action = outline.action as? PDFActionGoTo,
        let page = action.destination.page
      {
        let index = document.index(for: page)
        guard index != NSNotFound, index >= 0, index < document.pageCount else {
          return nil
        }
        return index
      }

      return nil
    }

    private func localizedPageLabel(_ pageNumber: Int) -> String {
      let format = String(localized: "Page %d", bundle: .main, comment: "Fallback TOC title")
      return String.localizedStringWithFormat(format, pageNumber)
    }
  }
#endif
