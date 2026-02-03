//
//  DivinaReaderView.swift
//  Komga
//
//  Created by Komga iOS Client
//

import SwiftUI

struct DivinaReaderView: View {
  let book: Book
  let incognito: Bool
  let readList: ReadList?
  let onClose: (() -> Void)?

  @Environment(\.dismiss) private var dismiss
  @Environment(ReaderPresentationManager.self) private var readerPresentation

  @AppStorage("currentAccount") private var current: Current = .init()
  @AppStorage("readerBackground") private var readerBackground: ReaderBackground = .system
  @AppStorage("webtoonPageWidthPercentage") private var webtoonPageWidthPercentage: Double = 100.0
  #if os(iOS)
    @AppStorage("pageTransitionStyle") private var pageTransitionStyle: PageTransitionStyle = .scroll
  #endif
  @AppStorage("showTapZoneHints") private var showTapZoneHints: Bool = true
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false
  @AppStorage("shakeToOpenLiveText") private var shakeToOpenLiveText: Bool = false
  #if os(iOS)
    @AppStorage("autoHideControls") private var autoHideControls: Bool = false
  #else
    private let autoHideControls: Bool = false
  #endif

  @State private var readingDirection: ReadingDirection
  @State private var pageLayout: PageLayout
  @State private var isolateCoverPage: Bool
  @State private var splitWidePageMode: SplitWidePageMode

  @State private var currentBookId: String
  @State private var viewModel = ReaderViewModel()
  @State private var showingControls = true
  @State private var controlsTimer: Timer?
  @State private var currentSeries: Series?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var previousBook: Book?
  @State private var isAtBottom = false
  @State private var showTapZoneOverlay = false
  @State private var tapZoneOverlayTimer: Timer?

  @State private var showKeyboardHelp = false
  @State private var keyboardHelpTimer: Timer?
  @State private var preserveReaderOptions = false

  // UI Panels states
  @State private var showingPageJumpSheet = false
  @State private var showingTOCSheet = false
  @State private var showingReaderSettingsSheet = false
  @State private var showingDetailSheet = false

  #if os(tvOS)
    @State private var isEndPageButtonFocused = false
    private enum ReaderFocusAnchor: Hashable {
      case contentGuard
    }
    @FocusState private var readerFocusAnchor: ReaderFocusAnchor?
  #endif

  init(
    book: Book,
    incognito: Bool = false,
    readList: ReadList? = nil,
    onClose: (() -> Void)? = nil
  ) {
    self.book = book
    self.incognito = incognito
    self.readList = readList
    self.onClose = onClose
    self._currentBookId = State(initialValue: book.id)
    self._currentBook = State(initialValue: book)
    self._readingDirection = State(initialValue: AppConfig.defaultReadingDirection)
    self._pageLayout = State(initialValue: AppConfig.pageLayout)
    self._isolateCoverPage = State(initialValue: AppConfig.isolateCoverPage)
    self._splitWidePageMode = State(initialValue: AppConfig.splitWidePageMode)
  }

  var shouldShowControls: Bool {
    // Always show controls when no pages are loaded or when explicitly shown
    #if os(tvOS)
      // On tvOS, don't force controls at endpage to allow navigation back
      !viewModel.isZoomed
        && (viewModel.pages.isEmpty || showingControls || (readingDirection == .webtoon && isAtBottom))
    #else
      !viewModel.isZoomed
        && (viewModel.pages.isEmpty || showingControls || isShowingEndPage
          || (readingDirection == .webtoon && isAtBottom))
    #endif
  }

  private var handoffBookId: String {
    currentBook?.id ?? book.id
  }

  private var handoffTitle: String {
    currentBook?.metadata.title ?? book.metadata.title
  }

  private var handoffPageNumber: Int? {
    viewModel.currentPage?.number
  }

  private var isShowingEndPage: Bool {
    guard !viewModel.pages.isEmpty else { return false }
    return viewModel.currentPageIndex >= viewModel.pages.count
  }

  private func shouldUseDualPage(screenSize: CGSize) -> Bool {
    guard screenSize.width > screenSize.height else { return false }  // Only in landscape
    guard pageLayout != .single else { return false }
    return readingDirection != .vertical
  }

  private func updateHandoff() {
    let url = KomgaWebLinkBuilder.bookReader(
      serverURL: current.serverURL,
      bookId: handoffBookId,
      pageNumber: handoffPageNumber,
      incognito: incognito
    )
    readerPresentation.updateHandoff(title: handoffTitle, url: url)
  }

  private func closeReader() {
    if let onClose {
      onClose()
    } else {
      dismiss()
    }
  }

  private func applyStatusBarVisibility(controlsHidden: Bool) {
    withAnimation {
      readerPresentation.hideStatusBar = controlsHidden
    }
  }

  private func resetReaderPreferencesForCurrentBook() {
    pageLayout = AppConfig.pageLayout
    viewModel.updatePageLayout(pageLayout)
    isolateCoverPage = AppConfig.isolateCoverPage
    splitWidePageMode = AppConfig.splitWidePageMode
    viewModel.updateSplitWidePageMode(splitWidePageMode)
    readingDirection = AppConfig.defaultReadingDirection
  }

  private func screenKey(screenSize: CGSize) -> String {
    return "\(Int(screenSize.width))x\(Int(screenSize.height))"
  }

  #if os(tvOS)
    private var endPageFocusChangeHandler: ((Bool) -> Void) {
      { isFocused in
        // isFocused is true when any button in EndPageView has focus
        isEndPageButtonFocused = isFocused
      }
    }
  #else
    private var endPageFocusChangeHandler: ((Bool) -> Void)? {
      nil
    }
  #endif

  var body: some View {
    GeometryReader { geometry in
      let screenSize = geometry.size
      let screenKey = screenKey(screenSize: screenSize)
      let useDualPage = shouldUseDualPage(screenSize: screenSize)

      ZStack {
        readerBackground.color.readerIgnoresSafeArea()
        #if os(tvOS)
          // Invisible focus anchor that receives focus when controls are hidden.
          Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .focusable(true)
            .focused($readerFocusAnchor, equals: .contentGuard)
            .opacity(0.001)
        #endif

        readerContent(
          useDualPage: useDualPage,
          screenKey: screenKey
        )

        helperOverlay(screenKey: screenKey)

        controlsOverlay(useDualPage: useDualPage)

        #if os(macOS)
          keyboardHelpOverlay
        #endif
      }
      #if os(tvOS)
        .onPlayPauseCommand {
          // Manual toggle on tvOS should not auto-hide
          toggleControls(autoHide: false)
        }
        .onExitCommand {
          // Back button hides controls first; second press dismisses reader
          if showingControls {
            toggleControls(autoHide: false)
          } else {
            closeReader()
          }
        }
        .onMoveCommand { direction in
          if showingControls {
            return
          }
          if isEndPageButtonFocused {
            return
          }

          // Execute page navigation
          switch readingDirection {
          case .ltr, .rtl:
            // Horizontal navigation
            switch direction {
            case .left:
              // RTL: left means next, LTR: left means previous
              if readingDirection == .rtl {
                goToNextPage()
              } else {
                goToPreviousPage()
              }
            case .right:
              // RTL: right means previous, LTR: right means next
              if readingDirection == .rtl {
                goToPreviousPage()
              } else {
                goToNextPage()
              }
            default:
              break
            }
          case .vertical:
            // Vertical navigation
            switch direction {
            case .up:
              goToPreviousPage()
            case .down:
              goToNextPage()
            default:
              break
            }
          case .webtoon:
            // Webtoon navigation (vertical)
            switch direction {
            case .up:
              goToPreviousPage()
            case .down:
              goToNextPage()
            default:
              break
            }
          }
        }
      #endif
      #if os(macOS)
        .background(
          // Window-level keyboard event handler
          KeyboardEventHandler(
            onKeyPress: { keyCode, flags in
              handleKeyCode(keyCode, flags: flags)
            }
          )
        )
      #endif
    }
    .iPadIgnoresSafeArea()
    #if os(iOS)
      .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
        if shakeToOpenLiveText {
          enableLiveText.toggle()
          let message = enableLiveText ? String(localized: "Live Text: ON") : String(localized: "Live Text: OFF")
          ErrorManager.shared.notify(message: message)
        }
      }
    #endif
    .sheet(isPresented: $showingPageJumpSheet) {
      PageJumpSheetView(
        bookId: currentBookId,
        totalPages: viewModel.pages.count,
        currentPage: min(viewModel.currentPageIndex + 1, viewModel.pages.count),
        readingDirection: readingDirection,
        viewModel: viewModel,
        onJump: jumpToPage
      )
    }
    .sheet(isPresented: $showingTOCSheet) {
      DivinaTOCSheetView(
        entries: viewModel.tableOfContents,
        currentPageIndex: viewModel.currentPageIndex,
        onSelect: { entry in
          showingTOCSheet = false
          jumpToTOCEntry(entry)
        }
      )
    }
    .sheet(isPresented: $showingReaderSettingsSheet) {
      ReaderSettingsSheet(readingDirection: $readingDirection)
    }
    .readerDetailSheet(
      isPresented: $showingDetailSheet,
      book: currentBook,
      series: currentSeries
    )
    .onAppear {
      viewModel.updateDualPageSettings(noCover: !isolateCoverPage)
      updateHandoff()
      #if os(tvOS)
        updateContentFocusAnchor()
      #endif
    }
    .onChange(of: isolateCoverPage) { _, newValue in
      viewModel.updateDualPageSettings(noCover: !newValue)
    }
    .onChange(of: pageLayout) { _, newValue in
      viewModel.updatePageLayout(newValue)
    }
    .onChange(of: splitWidePageMode) { _, newValue in
      viewModel.updateSplitWidePageMode(newValue)
    }
    .task(id: currentBookId) {
      if !preserveReaderOptions {
        resetReaderPreferencesForCurrentBook()
      }
      await loadBook(bookId: currentBookId, preserveReaderOptions: preserveReaderOptions)
      preserveReaderOptions = false
    }
    .onChange(of: currentBook?.id) { _, _ in
      updateHandoff()
    }
    .onChange(of: viewModel.pages.count) { oldCount, newCount in
      // Show helper overlay when pages are first loaded (iOS and macOS)
      if oldCount == 0 && newCount > 0 {
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 1.5)
        forceInitialAutoHide(timeout: 1.5)
      }
    }
    .onDisappear {
      controlsTimer?.invalidate()
      tapZoneOverlayTimer?.invalidate()
      keyboardHelpTimer?.invalidate()
      viewModel.clearPreloadedImages()
    }
    .onChange(of: showingControls) { _, newValue in
      applyStatusBarVisibility(controlsHidden: !newValue)
    }
    .onChange(of: viewModel.isZoomed) { _, newValue in
      if newValue {
        showingControls = false
      }
    }
    #if os(iOS)
      .onChange(of: autoHideControls) { _, newValue in
        if newValue {
          resetControlsTimer(timeout: 3)
        } else {
          controlsTimer?.invalidate()
        }
      }
    #endif
    #if os(iOS)
      .onAppear {
        if readingDirection != readerPresentation.readingDirection {
          readerPresentation.readingDirection = readingDirection
        }
      }
    #endif
    #if os(iOS) || os(macOS)
      .onChange(of: readingDirection) { _, newDirection in
        // When switching read mode via settings, briefly show overlays again
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 2)
        if readingDirection != readerPresentation.readingDirection {
          readerPresentation.readingDirection = newDirection
        }
      }
    #endif
    #if os(macOS) || os(tvOS)
      .onChange(of: showingControls) { oldValue, newValue in
        // On macOS and tvOS, if controls are manually shown (from false to true),
        // cancel auto-hide timer to prevent auto-hiding
        if newValue && !oldValue {
          // User manually opened controls (via C key on macOS or play/pause on tvOS),
          // cancel any existing auto-hide timer
          controlsTimer?.invalidate()
        }
        #if os(tvOS)
          updateContentFocusAnchor()
        #endif
      }
    #endif
    #if os(macOS)
      .onChange(of: currentBook) { _, newBook in
        // Update window manager state when book changes to refresh window title
        if let book = newBook {
          ReaderWindowManager.shared.currentState = BookReaderState(
            book: book, incognito: incognito, readList: readList)
        }
      }
    #endif
    .environment(\.readerBackgroundPreference, readerBackground)
  }

  @ViewBuilder
  private func readerContent(
    useDualPage: Bool,
    screenKey: String
  ) -> some View {
    let _ = viewModel.updateActualDualPageMode(useDualPage)

    Group {
      if !viewModel.pages.isEmpty {
        Group {
          if readingDirection == .webtoon {
            #if os(iOS) || os(macOS)
              WebtoonPageView(
                viewModel: viewModel,
                isAtBottom: $isAtBottom,
                nextBook: nextBook,
                readList: readList,
                onDismiss: { closeReader() },
                onNextBook: { openNextBook(nextBookId: $0) },
                toggleControls: { toggleControls() },
                pageWidthPercentage: webtoonPageWidthPercentage,
                readerBackground: readerBackground
              )
            #else
              ScrollPageView(
                mode: .vertical,
                readingDirection: readingDirection,
                splitWidePageMode: splitWidePageMode,
                viewModel: viewModel,
                nextBook: nextBook,
                readList: readList,
                onDismiss: { closeReader() },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: { goToNextPage() },
                goToPreviousPage: { goToPreviousPage() },
                toggleControls: { toggleControls() },
                onEndPageFocusChange: endPageFocusChangeHandler,
                onScrollActivityChange: { isScrolling in
                  if isScrolling {
                    resetControlsTimer(timeout: 1.5)
                  }
                }
              )
            #endif
          } else {
            #if os(iOS)
              if pageTransitionStyle == .pageCurl && !useDualPage {
                CurlPageView(
                  viewModel: viewModel,
                  mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                  readingDirection: readingDirection,
                  splitWidePageMode: splitWidePageMode,
                  nextBook: nextBook,
                  readList: readList,
                  onDismiss: { closeReader() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage() },
                  goToPreviousPage: { goToPreviousPage() },
                  toggleControls: { toggleControls() },
                  onEndPageFocusChange: endPageFocusChangeHandler
                )
              } else {
                ScrollPageView(
                  mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                  readingDirection: readingDirection,
                  splitWidePageMode: splitWidePageMode,
                  viewModel: viewModel,
                  nextBook: nextBook,
                  readList: readList,
                  onDismiss: { closeReader() },
                  onNextBook: { openNextBook(nextBookId: $0) },
                  goToNextPage: { goToNextPage() },
                  goToPreviousPage: { goToPreviousPage() },
                  toggleControls: { toggleControls() },
                  onEndPageFocusChange: endPageFocusChangeHandler,
                  onScrollActivityChange: { isScrolling in
                    if isScrolling {
                      resetControlsTimer(timeout: 1.5)
                    }
                  }
                )
              }
            #else
              ScrollPageView(
                mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                readingDirection: readingDirection,
                splitWidePageMode: splitWidePageMode,
                viewModel: viewModel,
                nextBook: nextBook,
                readList: readList,
                onDismiss: { closeReader() },
                onNextBook: { openNextBook(nextBookId: $0) },
                goToNextPage: { goToNextPage() },
                goToPreviousPage: { goToPreviousPage() },
                toggleControls: { toggleControls() },
                onEndPageFocusChange: endPageFocusChangeHandler,
                onScrollActivityChange: { isScrolling in
                  if isScrolling {
                    resetControlsTimer(timeout: 1.5)
                  }
                }
              )
            #endif
          }
        }
        .readerIgnoresSafeArea()
        .id("\(currentBookId)-\(screenKey)-\(readingDirection)")
        .onChange(of: viewModel.currentPageIndex) {
          updateHandoff()
          // Update progress and preload pages in background without blocking UI
          Task(priority: .userInitiated) {
            await viewModel.updateProgress()
            await viewModel.preloadPages()
          }
        }
      } else if viewModel.isLoading {
        ReaderLoadingView(
          title: String(localized: "Loading book..."),
          detail: nil,
          progress: nil
        )
      } else {
        NoPagesView(onDismiss: { closeReader() })
      }
    }
  }

  @ViewBuilder
  private func helperOverlay(screenKey: String) -> some View {
    #if os(iOS) || os(macOS)
      TapZoneOverlay(isVisible: $showTapZoneOverlay, readingDirection: readingDirection)
        .readerIgnoresSafeArea()
        .onChange(of: screenKey) {
          // Show helper overlay when screen orientation changes
          triggerTapZoneOverlay(timeout: 1)
        }
        .onChange(of: tapZoneMode) {
          // Show helper overlay when tap zone mode changes
          triggerTapZoneOverlay(timeout: 1)
        }
    #else
      EmptyView()
    #endif
  }

  private func controlsOverlay(useDualPage: Bool) -> some View {
    DivinaControlsOverlayView(
      readingDirection: $readingDirection,
      pageLayout: $pageLayout,
      isolateCoverPage: $isolateCoverPage,
      splitWidePageMode: $splitWidePageMode,
      showingPageJumpSheet: $showingPageJumpSheet,
      showingTOCSheet: $showingTOCSheet,
      showingReaderSettingsSheet: $showingReaderSettingsSheet,
      showingDetailSheet: $showingDetailSheet,
      viewModel: viewModel,
      currentBook: currentBook,
      dualPage: useDualPage,
      incognito: incognito,
      onDismiss: { closeReader() },
      previousBook: previousBook,
      nextBook: nextBook,
      onPreviousBook: { openPreviousBook(previousBookId: $0) },
      onNextBook: { openNextBook(nextBookId: $0) },
      controlsVisible: shouldShowControls,
      showingControls: showingControls
    )
  }

  #if os(macOS)
    private var keyboardHelpOverlay: some View {
      KeyboardHelpOverlay(
        readingDirection: readingDirection,
        hasTOC: !viewModel.tableOfContents.isEmpty,
        hasNextBook: nextBook != nil,
        onDismiss: {
          hideKeyboardHelp()
        }
      )
      .opacity(showKeyboardHelp ? 1.0 : 0.0)
      .allowsHitTesting(showKeyboardHelp)
      .animation(.default, value: showKeyboardHelp)
    }

    private func handleKeyCode(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) {
      // Handle ESC key to close window
      if keyCode == 53 {  // ESC key
        closeReader()
        return
      }

      // Handle ? key and H key for keyboard help
      if keyCode == 44 {  // ? key (Shift + /)
        showKeyboardHelp.toggle()
        return
      }

      // Handle Return/Enter key for fullscreen toggle
      if keyCode == 36 {  // Return/Enter key
        if let window = NSApplication.shared.keyWindow {
          window.toggleFullScreen(nil)
        }
        return
      }

      // Handle Space key for toggle controls
      if keyCode == 49 {  // Space key
        toggleControls()
        return
      }

      // Ignore if modifier keys are pressed (except for system shortcuts)
      guard flags.intersection([.command, .option, .control]).isEmpty else { return }

      // Handle F key for fullscreen toggle
      if keyCode == 3 {  // F key
        if let window = NSApplication.shared.keyWindow {
          window.toggleFullScreen(nil)
        }
        return
      }

      // Handle H key for keyboard help
      if keyCode == 4 {  // H key
        showKeyboardHelp.toggle()
        return
      }

      // Handle C key for toggle controls
      if keyCode == 8 {  // C key
        toggleControls()
        return
      }

      if keyCode == 37 {  // L key
        enableLiveText.toggle()
        let message = enableLiveText ? String(localized: "Live Text: ON") : String(localized: "Live Text: OFF")
        ErrorManager.shared.notify(message: message)
        return
      }

      // Handle T key for TOC
      if keyCode == 17 {  // T key
        if !viewModel.tableOfContents.isEmpty {
          showingTOCSheet = true
        }
        return
      }

      // Handle J key for jump to page
      if keyCode == 38 {  // J key
        if !viewModel.pages.isEmpty {
          showingPageJumpSheet = true
        }
        return
      }

      // Handle N key for next book
      if keyCode == 45 {  // N key
        if let nextBook = nextBook {
          openNextBook(nextBookId: nextBook.id)
        }
        return
      }

      guard !viewModel.pages.isEmpty else { return }

      switch readingDirection {
      case .ltr:
        switch keyCode {
        case 124:  // Right arrow
          goToNextPage()
        case 123:  // Left arrow
          goToPreviousPage()
        default:
          break
        }
      case .rtl:
        switch keyCode {
        case 123:  // Left arrow
          goToNextPage()
        case 124:  // Right arrow
          goToPreviousPage()
        default:
          break
        }
      case .vertical:
        switch keyCode {
        case 125:  // Down arrow
          goToNextPage()
        case 126:  // Up arrow
          goToPreviousPage()
        default:
          break
        }
      case .webtoon:
        // Webtoon scrolling is handled by WebtoonReaderView's own keyboard monitor
        break
      }
    }
  #endif

  private func loadBook(bookId: String, preserveReaderOptions: Bool) async {
    // Mark that loading has started
    viewModel.isLoading = true

    // Set incognito mode
    viewModel.incognitoMode = incognito

    // Reset isAtBottom when switching to a new book
    isAtBottom = false

    // Load book info to get read progress page and series reading direction
    var initialPageNumber: Int? = nil

    // 1. Use current book if it matches, otherwise try DB/network
    if let book = currentBook, book.id == bookId {
      seriesId = book.seriesId
      readerPresentation.trackVisitedBook(bookId: book.id, seriesId: book.seriesId)
      initialPageNumber = incognito ? nil : book.readProgress?.page
    } else if let book = await DatabaseOperator.shared.fetchBook(id: bookId) {
      currentBook = book
      seriesId = book.seriesId
      readerPresentation.trackVisitedBook(bookId: book.id, seriesId: book.seriesId)
      initialPageNumber = incognito ? nil : book.readProgress?.page
    } else if !AppConfig.isOffline {
      // 2. Fetch from network if not in DB and online
      do {
        let book = try await SyncService.shared.syncBook(bookId: bookId)
        currentBook = book
        seriesId = book.seriesId
        readerPresentation.trackVisitedBook(bookId: book.id, seriesId: book.seriesId)
        initialPageNumber = incognito ? nil : book.readProgress?.page
      } catch {
        // Fail silently
      }
    }

    if let activeBook = currentBook {
      // Refresh Divina manifest if online
      if !AppConfig.isOffline {
        do {
          let manifest = try await BookService.shared.getBookManifest(id: activeBook.id)
          let toc = await ReaderManifestService(bookId: activeBook.id).parseTOC(manifest: manifest)
          await DatabaseOperator.shared.updateBookTOC(bookId: activeBook.id, toc: toc)
        } catch {
          // Silently fail - we'll use cached manifest
        }
      }

      // 3. Try to get series from DB
      var series = await DatabaseOperator.shared.fetchSeries(id: activeBook.seriesId)
      if series == nil && !AppConfig.isOffline {
        series = try? await SyncService.shared.syncSeriesDetail(seriesId: activeBook.seriesId)
      }

      if let series = series {
        currentSeries = series
        let preferredDirection: ReadingDirection
        if AppConfig.forceDefaultReadingDirection {
          preferredDirection = AppConfig.defaultReadingDirection
        } else {
          let rawReadingDirection = series.metadata.readingDirection?
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
          if let rawReadingDirection, !rawReadingDirection.isEmpty {
            preferredDirection = ReadingDirection.fromString(rawReadingDirection)
          } else {
            preferredDirection = AppConfig.defaultReadingDirection
          }
        }

        if !preserveReaderOptions {
          readingDirection = preferredDirection.isSupported ? preferredDirection : .vertical
        }
      }

      // 4. Try to get next/previous books from DB
      self.nextBook = await DatabaseOperator.shared.getNextBook(
        instanceId: AppConfig.current.instanceId,
        bookId: bookId,
        readListId: readList?.id
      )
      if self.nextBook == nil && !AppConfig.isOffline {
        self.nextBook = await SyncService.shared.syncNextBook(
          bookId: bookId, readListId: readList?.id)
      }

      self.previousBook = await DatabaseOperator.shared.getPreviousBook(
        instanceId: AppConfig.current.instanceId,
        bookId: bookId,
        readListId: readList?.id
      )
      if self.previousBook == nil && !AppConfig.isOffline {
        self.previousBook = await SyncService.shared.syncPreviousBook(bookId: bookId)
      }
    }

    let resumePageNumber = viewModel.currentPage?.number ?? initialPageNumber

    guard let activeBook = currentBook, activeBook.id == bookId else {
      viewModel.isLoading = false
      return
    }

    await viewModel.loadPages(
      book: activeBook,
      initialPageNumber: resumePageNumber
    )

    // Only preload pages if pages are available
    if viewModel.pages.isEmpty {
      return
    }
    await viewModel.preloadPages()
  }

  private func jumpToPage(page: Int) {
    guard !viewModel.pages.isEmpty else { return }
    let clampedPage = min(max(page, 1), viewModel.pages.count)
    let targetIndex = clampedPage - 1
    if targetIndex != viewModel.currentPageIndex {
      viewModel.targetPageIndex = targetIndex
    }
  }

  private func jumpToTOCEntry(_ entry: ReaderTOCEntry) {
    jumpToPage(page: entry.pageIndex + 1)
  }

  private func goToNextPage() {
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      let currentIndex =
        viewModel.currentViewItemIndex < viewModel.viewItems.count
        ? viewModel.currentViewItemIndex
        : viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)
      let nextIndex = currentIndex + 1
      guard nextIndex < viewModel.viewItems.count else { return }
      viewModel.targetViewItemIndex = nextIndex
    case .webtoon:
      // webtoon do not have an end page
      let next = min(viewModel.currentPageIndex + 1, viewModel.pages.count - 1)
      withAnimation {
        viewModel.currentPageIndex = next
      }
    }
  }

  private func goToPreviousPage() {
    guard !viewModel.pages.isEmpty else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical:
      let currentIndex =
        viewModel.currentViewItemIndex < viewModel.viewItems.count
        ? viewModel.currentViewItemIndex
        : viewModel.viewItemIndex(forPageIndex: viewModel.currentPageIndex)
      let previousIndex = currentIndex - 1
      guard previousIndex >= 0 else { return }
      viewModel.targetViewItemIndex = previousIndex
    case .webtoon:
      guard viewModel.currentPageIndex > 0 else { return }
      withAnimation {
        viewModel.currentPageIndex -= 1
      }
    }
  }

  #if os(tvOS)
    private func updateContentFocusAnchor() {
      readerFocusAnchor = showingControls ? nil : .contentGuard
    }
  #endif

  #if os(tvOS)
    private func toggleControls(autoHide: Bool = true) {
      // On tvOS, allow toggling controls even at endpage to enable navigation back
      // Only prevent hiding for webtoon at bottom
      if readingDirection == .webtoon && isAtBottom {
        return
      }
      withAnimation {
        showingControls.toggle()
      }
      if showingControls {
        // On tvOS, manual toggle should not auto-hide
        // Cancel any existing timer when manually opened
        controlsTimer?.invalidate()
      }
    }
  #else
    private func toggleControls(autoHide: Bool = true) {
      // Don't hide controls when at end page or webtoon at bottom
      if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
        return
      }
      withAnimation {
        showingControls.toggle()
      }
      if showingControls {
        // Only auto-hide if autoHide is true
        // On macOS, manual toggle should not auto-hide
        if autoHide {
          resetControlsTimer(timeout: 3)
        } else {
          // Cancel any existing timer when manually opened
          controlsTimer?.invalidate()
        }
      }
    }
  #endif

  private func forceInitialAutoHide(timeout: TimeInterval) {
    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      Task { @MainActor in
        withAnimation {
          showingControls = false
        }
      }
    }
  }

  private func resetControlsTimer(timeout: TimeInterval) {
    // Don't start timer if auto-hide is disabled
    if !autoHideControls {
      return
    }

    // Don't start timer when at end page or webtoon at bottom
    if isShowingEndPage || (readingDirection == .webtoon && isAtBottom) {
      return
    }

    controlsTimer?.invalidate()
    controlsTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      Task { @MainActor in
        withAnimation {
          showingControls = false
        }
      }
    }
  }

  /// Hide helper overlay and cancel timer
  private func hideTapZoneOverlay() {
    tapZoneOverlayTimer?.invalidate()
    withAnimation {
      showTapZoneOverlay = false
    }
  }

  /// Show reader helper overlay (Tap zones on iOS, keyboard help on macOS)
  private func triggerTapZoneOverlay(timeout: TimeInterval) {
    // Respect user preference and ensure we have content
    guard showTapZoneHints, !viewModel.pages.isEmpty else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      withAnimation {
        self.showTapZoneOverlay = true
      }
      self.resetTapZoneOverlayTimer(timeout: timeout)
    }
  }

  /// Auto-hide helper overlay after a platform-specific delay
  private func resetTapZoneOverlayTimer(timeout: TimeInterval) {
    tapZoneOverlayTimer?.invalidate()
    tapZoneOverlayTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      DispatchQueue.main.async {
        self.hideTapZoneOverlay()
      }
    }
  }

  /// Hide keyboard help overlay and cancel timer
  private func hideKeyboardHelp() {
    keyboardHelpTimer?.invalidate()
    withAnimation {
      showKeyboardHelp = false
    }
  }

  /// Show keyboard help overlay
  private func triggerKeyboardHelp(timeout: TimeInterval) {
    // Respect user preference and ensure we have content
    guard showKeyboardHelpOverlay, !viewModel.pages.isEmpty else { return }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      withAnimation {
        self.showKeyboardHelp = true
      }
      self.resetKeyboardHelpTimer(timeout: timeout)
    }
  }

  /// Auto-hide keyboard help overlay after a delay
  private func resetKeyboardHelpTimer(timeout: TimeInterval) {
    keyboardHelpTimer?.invalidate()
    keyboardHelpTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
      DispatchQueue.main.async {
        self.hideKeyboardHelp()
      }
    }
  }

  private func openNextBook(nextBookId: String) {
    // Switch to next book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = nextBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(
      isolateCoverPage: isolateCoverPage,
      pageLayout: pageLayout,
      splitWidePageMode: splitWidePageMode
    )
    // Preserve incognito mode for next book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

  private func openPreviousBook(previousBookId: String) {
    // Switch to previous book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = previousBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(
      isolateCoverPage: isolateCoverPage,
      pageLayout: pageLayout,
      splitWidePageMode: splitWidePageMode
    )
    // Preserve incognito mode for previous book
    viewModel.incognitoMode = incognito
    // Reset isAtBottom so buttons hide until user scrolls to bottom
    isAtBottom = false
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

}
