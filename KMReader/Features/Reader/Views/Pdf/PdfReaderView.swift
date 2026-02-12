#if os(iOS) || os(macOS)
  import SwiftUI

  struct PdfReaderView: View {
    let book: Book
    let incognito: Bool
    let onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(ReaderPresentationManager.self) private var readerPresentation

    @AppStorage("currentAccount") private var current: Current = .init()
    @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
    @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 3.0
    @AppStorage("doubleTapZoomMode") private var doubleTapZoomMode: DoubleTapZoomMode = .fast
    @AppStorage("pageLayout") private var pageLayout: PageLayout = .auto
    @AppStorage("pageTransitionStyle") private var pageTransitionStyle: PageTransitionStyle = .scroll

    @State private var viewModel: PdfReaderViewModel
    @State private var readingDirection: ReadingDirection
    @State private var currentBook: Book?
    @State private var showingControls = false
    @State private var showingPageJumpSheet = false
    @State private var showingSearchSheet = false
    @State private var showingTOCSheet = false
    @State private var showingPreferencesSheet = false
    @State private var searchQuery = ""
    @State private var targetPageNumber: Int?
    @State private var navigationToken = UUID()

    private let logger = AppLogger(.reader)

    init(
      book: Book,
      incognito: Bool = false,
      onClose: (() -> Void)? = nil
    ) {
      self.book = book
      self.incognito = incognito
      self.onClose = onClose
      _viewModel = State(initialValue: PdfReaderViewModel(incognito: incognito))
      _readingDirection = State(initialValue: AppConfig.defaultReadingDirection)
      _currentBook = State(initialValue: book)
    }

    var body: some View {
      ZStack {
        readerBackground.color.readerIgnoresSafeArea()

        contentView

        controlsOverlay
      }
      .sheet(isPresented: $showingPageJumpSheet) {
        PdfPageJumpSheetView(
          totalPages: viewModel.pageCount,
          currentPage: viewModel.currentPageNumber,
          onJump: { page in
            requestPageNavigation(to: page)
          }
        )
      }
      .sheet(isPresented: $showingSearchSheet) {
        PdfSearchSheetView(
          query: $searchQuery,
          isSearching: viewModel.isSearching,
          results: viewModel.searchResults,
          onSearch: { query in
            runSearch(query: query)
          },
          onSelectResult: { result in
            requestPageNavigation(to: result.pageNumber)
          }
        )
      }
      .sheet(isPresented: $showingTOCSheet) {
        DivinaTOCSheetView(
          entries: viewModel.tableOfContents,
          currentPageIndex: max(0, viewModel.currentPageNumber - 1),
          onSelect: { entry in
            showingTOCSheet = false
            requestPageNavigation(to: entry.pageIndex + 1)
          }
        )
      }
      .sheet(isPresented: $showingPreferencesSheet) {
        ReaderSettingsSheet(readingDirection: $readingDirection, isPdfProfile: true)
      }
      .iPadIgnoresSafeArea()
      .task(id: book.id) {
        await loadBook()
      }
      .onAppear {
        if readerPresentation.readingDirection != readingDirection {
          readerPresentation.readingDirection = readingDirection
        }
        normalizeTransitionStyleIfNeeded()
        readerPresentation.hideStatusBar = false
        updateHandoff()
      }
      .onChange(of: readingDirection) { _, newDirection in
        if readerPresentation.readingDirection != newDirection {
          readerPresentation.readingDirection = newDirection
        }
      }
      .onReceive(NotificationCenter.default.publisher(for: .fileDownloadProgress)) { notification in
        viewModel.updateDownloadProgress(notification: notification)
      }
      .onChange(of: currentBook?.id) { _, _ in
        updateHandoff()
      }
      .onChange(of: viewModel.currentPageNumber) { _, _ in
        updateHandoff()
      }
      .onChange(of: shouldShowControls) { _, newValue in
        withAnimation {
          readerPresentation.hideStatusBar = !newValue
        }
      }
      .onDisappear {
        logger.debug(
          "👋 PDF reader disappeared for book \(book.id), page=\(viewModel.currentPageNumber)/\(viewModel.pageCount)"
        )
        viewModel.flushProgress()
        showingControls = false
        readerPresentation.hideStatusBar = false
      }
    }

    private var shouldShowControls: Bool {
      if viewModel.errorMessage != nil { return true }
      if viewModel.isLoading { return true }
      return showingControls
    }

    private var animation: Animation {
      .default
    }

    @ViewBuilder
    private var contentView: some View {
      if viewModel.isLoading {
        ReaderLoadingView(
          title: loadingTitle,
          detail: loadingDetail,
          progress: (viewModel.downloadBytesReceived > 0 || viewModel.downloadProgress > 0)
            ? viewModel.downloadProgress : nil
        )
      } else if let errorMessage = viewModel.errorMessage {
        VStack(spacing: 16) {
          Image(systemName: "exclamationmark.triangle")
            .font(.largeTitle)

          Text(errorMessage)
            .multilineTextAlignment(.center)

          HStack(spacing: 12) {
            Button("Retry") {
              Task {
                await loadBook()
              }
            }
            .adaptiveButtonStyle(.borderedProminent)

            Button("Close") {
              closeReader()
            }
            .adaptiveButtonStyle(.bordered)
          }
        }
        .padding()
      } else if let documentURL = viewModel.documentURL {
        PdfDocumentView(
          documentURL: documentURL,
          pageLayout: pageLayout,
          pageTransitionStyle: pageTransitionStyle,
          readingDirection: readingDirection,
          doubleTapZoomScale: CGFloat(doubleTapZoomScale),
          doubleTapZoomMode: doubleTapZoomMode,
          initialPageNumber: viewModel.initialPageNumber,
          targetPageNumber: targetPageNumber,
          navigationToken: navigationToken,
          onPageChange: { pageNumber, totalPages in
            viewModel.updateCurrentPage(pageNumber: pageNumber, totalPages: totalPages)
          },
          onSingleTap: { normalizedPoint in
            handleSingleTap(normalizedPoint: normalizedPoint)
          }
        )
        .id(documentURL.path)
        .readerIgnoresSafeArea()
      } else {
        ReaderUnavailableView(
          icon: "doc.richtext",
          title: "PDF file unavailable",
          message: String(localized: "Offline PDF file is missing. Please try downloading again."),
          onClose: closeReader
        )
      }
    }

    private var controlsOverlay: some View {
      PdfControlsOverlayView(
        readingDirection: $readingDirection,
        pageLayout: $pageLayout,
        showingPageJumpSheet: $showingPageJumpSheet,
        showingSearchSheet: $showingSearchSheet,
        showingTOCSheet: $showingTOCSheet,
        showingReaderSettingsSheet: $showingPreferencesSheet,
        currentBook: currentBook,
        fallbackTitle: readerTitle,
        incognito: incognito,
        currentPage: viewModel.currentPageNumber,
        pageCount: viewModel.pageCount,
        hasTOC: !viewModel.tableOfContents.isEmpty,
        canSearch: viewModel.documentURL != nil,
        controlsVisible: shouldShowControls,
        onDismiss: closeReader
      )
    }

    private var loadingTitle: String {
      switch viewModel.loadingStage {
      case .fetchingMetadata:
        return String(localized: "Fetching book info...")
      case .downloading:
        return String(localized: "Downloading book...")
      case .preparingReader:
        return String(localized: "Preparing PDF...")
      case .idle:
        return String(localized: "Loading book...")
      }
    }

    private var loadingDetail: String? {
      guard viewModel.loadingStage == .downloading else { return nil }
      guard viewModel.downloadBytesReceived > 0 else { return nil }

      let formatter = ByteCountFormatter()
      formatter.countStyle = .file
      let received = formatter.string(fromByteCount: viewModel.downloadBytesReceived)

      if let expected = viewModel.downloadBytesExpected, expected > 0 {
        let total = formatter.string(fromByteCount: expected)
        return "\(received) / \(total)"
      }

      return received
    }

    private func loadBook() async {
      var resolvedBook: Book = book

      if let cachedBook = await DatabaseOperator.shared.fetchBook(id: book.id) {
        resolvedBook = cachedBook
      }

      if !AppConfig.isOffline {
        if let syncedBook = try? await SyncService.shared.syncBook(bookId: book.id) {
          resolvedBook = syncedBook
        }
      }

      currentBook = resolvedBook
      readingDirection = await resolvePreferredReadingDirection(book: resolvedBook)
      await viewModel.load(book: resolvedBook)
      updateHandoff()
    }

    private func runSearch(query: String) {
      Task {
        await viewModel.search(text: query)
      }
    }

    private func toggleControls() {
      withAnimation(animation) {
        showingControls.toggle()
      }
    }

    private func handleSingleTap(normalizedPoint: CGPoint) {
      guard viewModel.pageCount > 0 else { return }

      let action = TapZoneHelper.action(
        normalizedX: normalizedPoint.x,
        normalizedY: normalizedPoint.y,
        tapZoneMode: AppConfig.tapZoneMode,
        readingDirection: tapReadingDirection(),
        zoneThreshold: AppConfig.tapZoneSize.value
      )

      switch action {
      case .previous:
        requestPageNavigation(to: viewModel.currentPageNumber - 1)
      case .next:
        requestPageNavigation(to: viewModel.currentPageNumber + 1)
      case .toggleControls:
        toggleControls()
      }
    }

    private func tapReadingDirection() -> ReadingDirection {
      readingDirection
    }

    private func normalizeTransitionStyleIfNeeded() {
      guard PageTransitionStyle.availableCases.contains(pageTransitionStyle) else {
        pageTransitionStyle = .scroll
        return
      }
    }

    private func normalizePdfReadingDirection(_ direction: ReadingDirection) -> ReadingDirection {
      direction
    }

    private func resolvePreferredReadingDirection(book: Book) async -> ReadingDirection {
      if AppConfig.forceDefaultReadingDirection {
        return normalizePdfReadingDirection(AppConfig.defaultReadingDirection)
      }

      var series = await DatabaseOperator.shared.fetchSeries(id: book.seriesId)
      if series == nil && !AppConfig.isOffline {
        series = try? await SyncService.shared.syncSeriesDetail(seriesId: book.seriesId)
      }

      if let rawReadingDirection = series?.metadata.readingDirection?
        .trimmingCharacters(in: .whitespacesAndNewlines),
        !rawReadingDirection.isEmpty
      {
        return normalizePdfReadingDirection(ReadingDirection.fromString(rawReadingDirection))
      }

      return normalizePdfReadingDirection(AppConfig.defaultReadingDirection)
    }

    private func requestPageNavigation(to page: Int) {
      guard viewModel.pageCount > 0 else { return }
      let clamped = max(1, min(page, viewModel.pageCount))
      guard clamped != viewModel.currentPageNumber else { return }
      targetPageNumber = clamped
      navigationToken = UUID()
      showingControls = false
    }

    private func closeReader() {
      logger.debug(
        "🚪 Closing PDF reader for book \(book.id), page=\(viewModel.currentPageNumber)/\(viewModel.pageCount)"
      )
      if let onClose {
        onClose()
      } else {
        dismiss()
      }
    }

    private func updateHandoff() {
      let handoffBook = currentBook ?? book
      let url = KomgaWebLinkBuilder.bookReader(
        serverURL: current.serverURL,
        bookId: handoffBook.id,
        pageNumber: viewModel.pageCount > 0 ? viewModel.currentPageNumber : nil,
        incognito: incognito
      )
      readerPresentation.updateHandoff(title: handoffBook.metadata.title, url: url)
    }

    private var readerTitle: String {
      let title = (currentBook?.metadata.title ?? book.metadata.title)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return title
    }
  }
#endif
