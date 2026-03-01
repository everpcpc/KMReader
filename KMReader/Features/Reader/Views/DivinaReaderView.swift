//
// DivinaReaderView.swift
//
//

import SwiftUI

struct DivinaReaderView: View {
  let book: Book
  let incognito: Bool
  let readListContext: ReaderReadListContext?
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
  @AppStorage("tapZoneSize") private var tapZoneSize: TapZoneSize = .large
  @AppStorage("tapZoneMode") private var tapZoneMode: TapZoneMode = .auto
  @AppStorage("showPageNumber") private var showPageNumber: Bool = true
  @AppStorage("showKeyboardHelpOverlay") private var showKeyboardHelpOverlay: Bool = true
  @AppStorage("enableLiveText") private var enableLiveText: Bool = false
  @AppStorage("autoPlayAnimatedImages") private var autoPlayAnimatedImages: Bool = false
  @AppStorage("doubleTapZoomScale") private var doubleTapZoomScale: Double = 3.0
  @AppStorage("doubleTapZoomMode") private var doubleTapZoomMode: DoubleTapZoomMode = .fast
  @AppStorage("shakeToOpenLiveText") private var shakeToOpenLiveText: Bool = false

  @State private var readingDirection: ReadingDirection
  @State private var pageLayout: PageLayout
  @State private var isolateCoverPage: Bool
  @State private var splitWidePageMode: SplitWidePageMode

  private let logger = AppLogger(.reader)

  @State private var currentBookId: String
  @State private var viewModel: ReaderViewModel
  @State private var showingControls = false
  @State private var currentSeries: Series?
  @State private var currentBook: Book?
  @State private var seriesId: String?
  @State private var nextBook: Book?
  @State private var previousBook: Book?
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
  @State private var animatedPlaybackURL: URL?
  @State private var animatedPlaybackLoading = false
  @State private var requestedNextSegmentPreloads: Set<String> = []
  @State private var requestedPreviousSegmentPreloads: Set<String> = []
  @State private var inFlightNextSegmentPreloads: Set<String> = []
  @State private var inFlightPreviousSegmentPreloads: Set<String> = []
  @State private var deferredPageMaintenanceTask: Task<Void, Never>?

  #if os(tvOS)
    @State private var lastTVRemoteMoveSignature: String = ""
    @State private var lastTVRemoteMoveTimestamp: TimeInterval = 0
    @State private var lastTVRemoteSelectTimestamp: TimeInterval = 0
    @State private var tvRemoteCaptureGeneration: Int = 0
  #endif

  init(
    book: Book,
    incognito: Bool = false,
    readListContext: ReaderReadListContext? = nil,
    onClose: (() -> Void)? = nil
  ) {
    self.book = book
    self.incognito = incognito
    self.readListContext = readListContext
    self.onClose = onClose
    self._currentBookId = State(initialValue: book.id)
    self._currentBook = State(initialValue: book)
    self._readingDirection = State(initialValue: AppConfig.defaultReadingDirection)
    self._pageLayout = State(initialValue: AppConfig.pageLayout)
    self._isolateCoverPage = State(initialValue: AppConfig.isolateCoverPage)
    self._splitWidePageMode = State(initialValue: AppConfig.splitWidePageMode)
    self._viewModel = State(
      initialValue: ReaderViewModel(
        isolateCoverPage: AppConfig.isolateCoverPage,
        pageLayout: AppConfig.pageLayout,
        splitWidePageMode: AppConfig.splitWidePageMode,
        incognitoMode: incognito
      )
    )
  }

  var shouldShowControls: Bool {
    !viewModel.isZoomed && (!viewModel.hasPages || showingControls)
  }

  private var renderConfig: ReaderRenderConfig {
    ReaderRenderConfig(
      tapZoneSize: tapZoneSize,
      tapZoneMode: tapZoneMode,
      showPageNumber: showPageNumber,
      autoPlayAnimatedImages: autoPlayAnimatedImages,
      readerBackground: readerBackground,
      enableLiveText: enableLiveText,
      doubleTapZoomScale: doubleTapZoomScale,
      doubleTapZoomMode: doubleTapZoomMode
    )
  }

  private var currentSegmentContext:
    (
      bookId: String, currentBook: Book?, previousBook: Book?, nextBook: Book?
    )
  {
    viewModel.activeSegmentContext(
      fallbackBookId: currentBookId,
      fallbackCurrentBook: currentBook,
      fallbackPreviousBook: previousBook,
      fallbackNextBook: nextBook
    )
  }

  private var currentSegmentBookId: String {
    currentSegmentContext.bookId
  }

  private var currentTOCSelection: ReaderTOCSelection {
    viewModel.currentTOCSelection(
      in: viewModel.tableOfContents,
      for: currentSegmentBookId
    )
  }

  private var currentSegmentBook: Book? {
    currentSegmentContext.currentBook
  }

  private var currentSegmentNextBook: Book? {
    currentSegmentContext.nextBook
  }

  private var currentSegmentPreviousBook: Book? {
    currentSegmentContext.previousBook
  }

  private var handoffBookId: String {
    currentSegmentBook?.id ?? currentBook?.id ?? book.id
  }

  private var handoffTitle: String {
    currentSegmentBook?.metadata.title ?? currentBook?.metadata.title ?? book.metadata.title
  }

  private var handoffPageNumber: Int? {
    viewModel.currentReaderPage?.pageNumber
  }

  private var isShowingEndPage: Bool {
    viewModel.currentViewItem()?.isEnd == true
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
    logger.debug(
      "🚪 Closing DIVINA reader for book \(currentBookId), currentPage=\(viewModel.currentPage?.number ?? -1), totalPages=\(viewModel.pageCount)"
    )
    if let onClose {
      onClose()
    } else {
      dismiss()
    }
  }

  private func schedulePageMaintenanceAfterPageChange() {
    deferredPageMaintenanceTask?.cancel()
    let delay: TimeInterval =
      readingDirection == .webtoon
      ? WebtoonConstants.postScrollCleanupDelay : 0
    deferredPageMaintenanceTask = Task(priority: .utility) {
      if delay > 0 {
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
      }
      guard !Task.isCancelled else { return }
      await viewModel.preloadPages()
      await preloadAdjacentSegmentsForCurrentPositionIfNeeded()
      await viewModel.ensureTableOfContentsForCurrentSegment()
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

  private func requestAnimatedPlayback(for pageID: ReaderPageID) {
    guard !animatedPlaybackLoading else { return }
    withAnimation(.easeInOut(duration: 0.18)) {
      animatedPlaybackLoading = true
    }

    Task {
      let fileURL = await viewModel.prepareAnimatedPagePlaybackURL(pageID: pageID)
      withAnimation(.easeInOut(duration: 0.18)) {
        animatedPlaybackLoading = false
      }
      guard let fileURL else {
        logger.debug("⚠️ Animated playback unavailable for pageID=\(pageID)")
        return
      }
      showingControls = false
      withAnimation(.easeInOut(duration: 0.22)) {
        animatedPlaybackURL = fileURL
      }
    }
  }

  private func dismissAnimatedPlayback() {
    withAnimation(.easeInOut(duration: 0.2)) {
      animatedPlaybackURL = nil
    }
  }

  #if os(tvOS)
    private var shouldEnableUIKitRemoteCapture: Bool {
      !showingPageJumpSheet
        && !showingTOCSheet
        && !showingReaderSettingsSheet
        && !showingDetailSheet
        && viewModel.hasPages
    }

    private func isBackwardTVMove(_ direction: MoveCommandDirection) -> Bool {
      switch readingDirection {
      case .ltr:
        return direction == .left
      case .rtl:
        return direction == .right
      case .vertical, .webtoon:
        return direction == .up
      }
    }

    private func shouldIgnoreDuplicateTVSelectCommand() -> Bool {
      let now = Date().timeIntervalSinceReferenceDate
      let isDuplicate = now - lastTVRemoteSelectTimestamp < 0.08
      lastTVRemoteSelectTimestamp = now
      return isDuplicate
    }

    private func shouldIgnoreDuplicateTVMoveCommand(_ direction: MoveCommandDirection) -> Bool {
      let now = Date().timeIntervalSinceReferenceDate
      let signature = String(describing: direction)
      let isDuplicate =
        lastTVRemoteMoveSignature == signature
        && now - lastTVRemoteMoveTimestamp < 0.08

      if isDuplicate {
        return true
      }

      lastTVRemoteMoveSignature = signature
      lastTVRemoteMoveTimestamp = now
      return false
    }

    private func handleTVMoveCommand(_ direction: MoveCommandDirection, source: String) -> Bool {
      logger.debug(
        "📺 \(source) move direction=\(String(describing: direction)), showingControls=\(showingControls), currentPageID=\(String(describing: viewModel.currentReaderPage?.id)), totalPages=\(viewModel.pageCount)"
      )

      if showingControls {
        logger.debug("📺 \(source) move ignored: controls are visible")
        return false
      }
      if !viewModel.hasPages {
        logger.debug("📺 \(source) move ignored: pages are empty")
        return false
      }

      if shouldIgnoreDuplicateTVMoveCommand(direction) {
        logger.debug("📺 \(source) move ignored: duplicate command")
        return true
      }

      if isShowingEndPage {
        if isBackwardTVMove(direction) {
          logger.debug("📺 \(source) move on end page: go to previous page")
          goToPreviousPage()
          return true
        }

        logger.debug("📺 \(source) move ignored on end page: non-backward direction")
        return false
      }

      switch readingDirection {
      case .ltr, .rtl:
        switch direction {
        case .left:
          if readingDirection == .rtl {
            goToNextPage()
          } else {
            goToPreviousPage()
          }
          return true
        case .right:
          if readingDirection == .rtl {
            goToPreviousPage()
          } else {
            goToNextPage()
          }
          return true
        default:
          return false
        }
      case .vertical:
        switch direction {
        case .up:
          goToPreviousPage()
          return true
        case .down:
          goToNextPage()
          return true
        default:
          return false
        }
      case .webtoon:
        switch direction {
        case .up:
          goToPreviousPage()
          return true
        case .down:
          goToNextPage()
          return true
        default:
          return false
        }
      }
    }

    private func handleTVSelectCommand(source: String) -> Bool {
      logger.debug(
        "📺 \(source) select, showingControls=\(showingControls), totalPages=\(viewModel.pageCount), currentPageID=\(String(describing: viewModel.currentReaderPage?.id))"
      )

      if shouldIgnoreDuplicateTVSelectCommand() {
        logger.debug("📺 \(source) select ignored: duplicate command")
        return true
      }

      if showingControls {
        logger.debug("📺 \(source) select ignored: controls are visible")
        return false
      }
      if !viewModel.hasPages {
        logger.debug("📺 \(source) select ignored: pages are empty")
        return false
      }
      if isShowingEndPage {
        logger.debug("📺 \(source) select on end page: toggle controls")
        toggleControls()
        return true
      }

      toggleControls()
      return true
    }
  #endif

  var body: some View {
    GeometryReader { geometry in
      let screenSize = geometry.size
      let screenKey = screenKey(screenSize: screenSize)
      let useDualPage = shouldUseDualPage(screenSize: screenSize)

      ZStack {
        readerBackground.color.readerIgnoresSafeArea()

        readerContent(
          useDualPage: useDualPage,
          screenKey: screenKey
        )

        #if os(tvOS)
          tvRemoteCommandOverlay
        #endif

        helperOverlay(screenKey: screenKey)

        controlsOverlay(useDualPage: useDualPage)

        if animatedPlaybackLoading {
          ProgressView()
            .padding(16)
            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .zIndex(20)
        }

        if let animatedPlaybackURL {
          AnimatedImagePlaybackOverlay(
            fileURL: animatedPlaybackURL,
            onClose: dismissAnimatedPlayback
          )
          .transition(.opacity)
          .zIndex(30)
        }

        #if os(macOS)
          keyboardHelpOverlay
        #endif
      }
      #if os(tvOS)
        .onPlayPauseCommand {
          logger.debug("📺 onPlayPauseCommand: toggling controls, showingControls=\(showingControls)")
          toggleControls()
        }
        .onExitCommand {
          logger.debug("📺 onExitCommand: showingControls=\(showingControls)")
          if showingControls {
            toggleControls()
          } else {
            closeReader()
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
        segmentBookId: currentSegmentBookId,
        currentPageID: viewModel.currentReaderPage?.id,
        readingDirection: readingDirection,
        viewModel: viewModel,
        onJump: jumpToPageID
      )
    }
    .sheet(isPresented: $showingTOCSheet) {
      DivinaTOCSheetView(
        entries: viewModel.tableOfContents,
        currentEntryIDs: currentTOCSelection.entryIDs,
        scrollTargetID: currentTOCSelection.scrollTargetID,
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
      book: currentSegmentBook,
      series: currentSeries
    )
    .onAppear {
      viewModel.updateDualPageSettings(noCover: !isolateCoverPage)
      updateHandoff()
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
      readerPresentation.setReaderFlushHandler {
        viewModel.flushProgress()
      }
      deferredPageMaintenanceTask?.cancel()
      deferredPageMaintenanceTask = nil
      requestedNextSegmentPreloads.removeAll()
      requestedPreviousSegmentPreloads.removeAll()
      if !preserveReaderOptions {
        resetReaderPreferencesForCurrentBook()
      }
      await loadBook(bookId: currentBookId, preserveReaderOptions: preserveReaderOptions)
      preserveReaderOptions = false
    }
    .onChange(of: currentBook?.id) { _, _ in
      updateHandoff()
    }
    .onChange(of: viewModel.pageCount) { oldCount, newCount in
      // Show helper overlay when pages are first loaded (iOS and macOS)
      if oldCount == 0 && newCount > 0 {
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 1.5)
      }
    }
    .onDisappear {
      logger.debug(
        "👋 DIVINA reader disappeared for book \(currentBookId), currentPage=\(viewModel.currentPage?.number ?? -1), totalPages=\(viewModel.pageCount)"
      )
      tapZoneOverlayTimer?.invalidate()
      keyboardHelpTimer?.invalidate()
      animatedPlaybackLoading = false
      animatedPlaybackURL = nil
      deferredPageMaintenanceTask?.cancel()
      deferredPageMaintenanceTask = nil
      viewModel.clearPreloadedImages()
    }
    .onChange(of: viewModel.isZoomed) { _, newValue in
      if newValue {
        showingControls = false
      }
    }
    .onChange(of: readingDirection) { _, _ in
      #if os(iOS) || os(macOS)
        // When switching read mode via settings, briefly show overlays again
        triggerTapZoneOverlay(timeout: 1)
        triggerKeyboardHelp(timeout: 2)
      #endif
    }
    #if os(tvOS)
      .onChange(of: shouldEnableUIKitRemoteCapture) { oldValue, newValue in
        if newValue && !oldValue {
          tvRemoteCaptureGeneration += 1
          logger.debug("📺 UIKit capture enabled, restart generation=\(tvRemoteCaptureGeneration)")
        }
      }
    #endif
    #if os(macOS)
      .onChange(of: currentBook) { _, newBook in
        // Update window manager state when book changes to refresh window title
        if let book = newBook {
          ReaderWindowManager.shared.currentState = BookReaderState(
            book: book, incognito: incognito, readListContext: readListContext)
        }
      }
    #endif
    #if os(iOS)
      .statusBarHidden(!shouldShowControls)
      .readerDismissGesture(readingDirection: readingDirection)
    #endif
    .environment(\.readerBackgroundPreference, readerBackground)
  }

  @ViewBuilder
  private func readerContent(
    useDualPage: Bool,
    screenKey: String
  ) -> some View {
    #if os(iOS)
      let useSplitPairInDualMode = pageTransitionStyle == .pageCurl && useDualPage
    #else
      let useSplitPairInDualMode = false
    #endif
    let _ = viewModel.updateCombineSplitWidePagePairInDualMode(useSplitPairInDualMode)
    let _ = viewModel.updateActualDualPageMode(useDualPage)

    Group {
      if viewModel.hasPages {
        Group {
          if readingDirection == .webtoon {
            #if os(iOS) || os(macOS)
              WebtoonPageView(
                viewModel: viewModel,
                readListContext: readListContext,
                onDismiss: { closeReader() },
                toggleControls: { toggleControls() },
                pageWidthPercentage: webtoonPageWidthPercentage,
                renderConfig: renderConfig
              )
            #else
              ScrollPageView(
                mode: .vertical,
                readingDirection: readingDirection,
                splitWidePageMode: splitWidePageMode,
                renderConfig: renderConfig,
                showingControls: showingControls,
                viewModel: viewModel,
                readListContext: readListContext,
                onDismiss: { closeReader() },
                toggleControls: { toggleControls() },
                onPlayAnimatedPage: { pageID in
                  requestAnimatedPlayback(for: pageID)
                },
                onScrollActivityChange: { _ in }
              )
            #endif
          } else {
            #if os(iOS)
              if pageTransitionStyle == .pageCurl {
                if useDualPage {
                  CurlDualPageView(
                    viewModel: viewModel,
                    mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                    readingDirection: readingDirection,
                    splitWidePageMode: splitWidePageMode,
                    renderConfig: renderConfig,
                    readListContext: readListContext,
                    onDismiss: { closeReader() },
                    onPlayAnimatedPage: { pageID in
                      requestAnimatedPlayback(for: pageID)
                    }
                  )
                } else {
                  CurlPageView(
                    viewModel: viewModel,
                    mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                    readingDirection: readingDirection,
                    splitWidePageMode: splitWidePageMode,
                    renderConfig: renderConfig,
                    readListContext: readListContext,
                    onDismiss: { closeReader() },
                    onPlayAnimatedPage: { pageID in
                      requestAnimatedPlayback(for: pageID)
                    }
                  )
                }
              } else {
                ScrollPageView(
                  mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                  readingDirection: readingDirection,
                  splitWidePageMode: splitWidePageMode,
                  renderConfig: renderConfig,
                  showingControls: showingControls,
                  viewModel: viewModel,
                  readListContext: readListContext,
                  onDismiss: { closeReader() },
                  toggleControls: { toggleControls() },
                  onPlayAnimatedPage: { pageID in
                    requestAnimatedPlayback(for: pageID)
                  },
                  onScrollActivityChange: { _ in }
                )
              }
            #else
              ScrollPageView(
                mode: PageViewMode(direction: readingDirection, useDualPage: useDualPage),
                readingDirection: readingDirection,
                splitWidePageMode: splitWidePageMode,
                renderConfig: renderConfig,
                showingControls: showingControls,
                viewModel: viewModel,
                readListContext: readListContext,
                onDismiss: { closeReader() },
                toggleControls: { toggleControls() },
                onPlayAnimatedPage: { pageID in
                  requestAnimatedPlayback(for: pageID)
                },
                onScrollActivityChange: { _ in }
              )
            #endif
          }
        }
        .readerIgnoresSafeArea()
        .id("\(currentBookId)-\(screenKey)-\(readingDirection)")
        #if os(iOS) || os(macOS)
          .background(
            DivinaTapZoneGestureBridge(
              isEnabled: isTapZoneGestureEnabled,
              readingDirection: readingDirection,
              tapZoneMode: tapZoneMode,
              tapZoneSize: tapZoneSize,
              doubleTapZoomMode: doubleTapZoomMode,
              enableLiveText: enableLiveText,
              onAction: handleTapZoneAction
            )
          )
        #endif
        .onChange(of: viewModel.currentReaderPage?.id) { _, _ in
          updateHandoff()
          // Keep progress sync responsive.
          Task(priority: .userInitiated) {
            await viewModel.updateProgress()
          }
          schedulePageMaintenanceAfterPageChange()
        }
        #if os(tvOS)
          .onChange(of: isShowingEndPage) { oldValue, newValue in
            if oldValue && !newValue {
              tvRemoteCaptureGeneration += 1
              logger.debug("📺 left end page, restart UIKit capture generation=\(tvRemoteCaptureGeneration)")
            }
          }
        #endif
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

  #if os(tvOS)
    private var tvRemoteCommandOverlay: some View {
      TVRemoteCommandOverlay(
        isEnabled: shouldEnableUIKitRemoteCapture,
        onMoveCommand: { direction in
          handleTVMoveCommand(direction, source: "uikit.overlay")
        },
        onSelectCommand: {
          handleTVSelectCommand(source: "uikit.overlay")
        }
      )
      .readerIgnoresSafeArea()
      .accessibilityHidden(true)
      .id(tvRemoteCaptureGeneration)
    }
  #endif

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
      currentBook: currentSegmentBook,
      dualPage: useDualPage,
      incognito: incognito,
      onDismiss: { closeReader() },
      previousBook: currentSegmentPreviousBook,
      nextBook: currentSegmentNextBook,
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
        hasNextBook: currentSegmentNextBook != nil,
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
        if viewModel.hasPages {
          showingPageJumpSheet = true
        }
        return
      }

      // Handle N key for next book
      if keyCode == 45 {  // N key
        if let nextBook = currentSegmentNextBook {
          openNextBook(nextBookId: nextBook.id)
        }
        return
      }

      guard viewModel.hasPages else { return }

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

    // Load book info to get read progress page and series reading direction
    var initialPageNumber: Int? = nil

    // Resolve from in-memory/DB first, then always refresh from network when online.
    var resolvedBook: Book?
    if let currentBook, currentBook.id == bookId {
      resolvedBook = currentBook
    } else if let cachedBook = await DatabaseOperator.shared.fetchBook(id: bookId) {
      resolvedBook = cachedBook
    } else if book.id == bookId {
      resolvedBook = book
    }

    if !AppConfig.isOffline {
      if let syncedBook = try? await SyncService.shared.syncBook(bookId: bookId) {
        resolvedBook = syncedBook
      }
    }

    if let resolvedBook {
      currentBook = resolvedBook
      seriesId = resolvedBook.seriesId
      if !incognito {
        readerPresentation.trackVisitedBook(bookId: resolvedBook.id, seriesId: resolvedBook.seriesId)
      }
      if incognito {
        initialPageNumber = nil
      } else if resolvedBook.readProgress?.completed == true {
        initialPageNumber = nil
      } else {
        initialPageNumber = resolvedBook.readProgress?.page
      }
    }

    if let activeBook = currentBook {
      let isBookDownloaded = await OfflineManager.shared.isBookDownloaded(bookId: activeBook.id)

      // Refresh Divina manifest only when online and the book is not downloaded offline.
      if !AppConfig.isOffline, !isBookDownloaded {
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

      // 4. Resolve adjacent books for current segment context
      let adjacentBooks = await resolveAdjacentBooks(for: bookId)
      self.previousBook = adjacentBooks.previous
      self.nextBook = adjacentBooks.next
    }

    let resumePageNumber = viewModel.currentPage?.number ?? initialPageNumber

    guard let activeBook = currentBook, activeBook.id == bookId else {
      viewModel.isLoading = false
      return
    }

    await viewModel.loadPages(
      book: activeBook,
      initialPageNumber: resumePageNumber,
      previousBook: previousBook,
      nextBook: nextBook
    )

    // Only preload pages if pages are available
    if !viewModel.hasPages {
      return
    }
    await viewModel.preloadPages()
    await preloadAdjacentSegmentsForCurrentPositionIfNeeded()
  }

  private func resolveAdjacentBooks(for bookId: String) async -> (previous: Book?, next: Book?) {
    let readListId = readListContext?.id
    let instanceId = AppConfig.current.instanceId

    var resolvedNextBook = await DatabaseOperator.shared.getNextBook(
      instanceId: instanceId,
      bookId: bookId,
      readListId: readListId
    )
    if resolvedNextBook == nil && !AppConfig.isOffline {
      resolvedNextBook = await SyncService.shared.syncNextBook(
        bookId: bookId,
        readListId: readListId
      )
    }

    var resolvedPreviousBook = await DatabaseOperator.shared.getPreviousBook(
      instanceId: instanceId,
      bookId: bookId,
      readListId: readListId
    )
    if resolvedPreviousBook == nil && !AppConfig.isOffline {
      resolvedPreviousBook = await SyncService.shared.syncPreviousBook(
        bookId: bookId,
        readListId: readListId
      )
    }

    return (resolvedPreviousBook, resolvedNextBook)
  }

  private var segmentPreloadTriggerDistance: Int {
    2
  }

  private func resolveSegmentPreloadContext(for segmentBookId: String) async -> (
    currentBook: Book, previousBook: Book?, nextBook: Book?
  )? {
    guard let segmentBook = viewModel.currentBook(forSegmentBookId: segmentBookId) else { return nil }

    var resolvedPreviousBook = viewModel.previousBook(forSegmentBookId: segmentBookId)
    var resolvedNextBook = viewModel.nextBook(forSegmentBookId: segmentBookId)

    if resolvedPreviousBook == nil || resolvedNextBook == nil {
      let adjacentBooks = await resolveAdjacentBooks(for: segmentBookId)
      resolvedPreviousBook = resolvedPreviousBook ?? adjacentBooks.previous
      resolvedNextBook = resolvedNextBook ?? adjacentBooks.next
    }

    return (
      currentBook: segmentBook,
      previousBook: resolvedPreviousBook,
      nextBook: resolvedNextBook
    )
  }

  private func resolveBookBefore(_ book: Book) async -> Book? {
    if let cachedPreviousBook = viewModel.previousBook(forSegmentBookId: book.id) {
      return cachedPreviousBook
    }
    let previousAdjacentBooks = await resolveAdjacentBooks(for: book.id)
    return previousAdjacentBooks.previous
  }

  private func preloadAdjacentSegmentsForCurrentPositionIfNeeded() async {
    await preloadPreviousSegmentForCurrentPositionIfNeeded()
    await preloadNextSegmentForCurrentPositionIfNeeded()
  }

  private func preloadPreviousSegmentForCurrentPositionIfNeeded() async {
    guard let currentReaderPage = viewModel.currentReaderPage else { return }
    let segmentBookId = currentReaderPage.bookId

    guard !requestedPreviousSegmentPreloads.contains(segmentBookId) else { return }
    guard !inFlightPreviousSegmentPreloads.contains(segmentBookId) else { return }
    guard let pagesFromSegmentStart = viewModel.currentPageOffsetInSegment(for: segmentBookId) else {
      return
    }
    guard pagesFromSegmentStart <= segmentPreloadTriggerDistance else { return }

    guard
      let preloadContext = await resolveSegmentPreloadContext(for: segmentBookId),
      let resolvedPreviousBook = preloadContext.previousBook
    else {
      requestedPreviousSegmentPreloads.insert(segmentBookId)
      return
    }

    inFlightPreviousSegmentPreloads.insert(segmentBookId)
    defer { inFlightPreviousSegmentPreloads.remove(segmentBookId) }

    let resolvedPreviousPreviousBook = await resolveBookBefore(resolvedPreviousBook)

    await viewModel.preloadPreviousSegmentIfNeeded(
      currentBook: preloadContext.currentBook,
      previousBook: resolvedPreviousBook,
      nextBook: preloadContext.nextBook,
      previousPreviousBook: resolvedPreviousPreviousBook
    )

    if viewModel.currentBook(forSegmentBookId: resolvedPreviousBook.id) != nil {
      requestedPreviousSegmentPreloads.insert(segmentBookId)
    }
  }

  private func preloadNextSegmentForCurrentPositionIfNeeded() async {
    guard let currentReaderPage = viewModel.currentReaderPage else { return }
    let segmentBookId = currentReaderPage.bookId

    guard !requestedNextSegmentPreloads.contains(segmentBookId) else { return }
    guard !inFlightNextSegmentPreloads.contains(segmentBookId) else { return }
    guard let remainingPagesInSegment = viewModel.remainingPagesInSegment(for: segmentBookId) else {
      return
    }
    guard remainingPagesInSegment <= segmentPreloadTriggerDistance else { return }

    guard
      let preloadContext = await resolveSegmentPreloadContext(for: segmentBookId),
      let resolvedNextBook = preloadContext.nextBook
    else {
      requestedNextSegmentPreloads.insert(segmentBookId)
      return
    }

    inFlightNextSegmentPreloads.insert(segmentBookId)
    defer { inFlightNextSegmentPreloads.remove(segmentBookId) }

    await viewModel.preloadNextSegmentIfNeeded(
      currentBook: preloadContext.currentBook,
      previousBook: preloadContext.previousBook,
      nextBook: resolvedNextBook
    )

    if viewModel.currentBook(forSegmentBookId: resolvedNextBook.id) != nil {
      requestedNextSegmentPreloads.insert(segmentBookId)
    }
  }

  private func jumpToPageID(_ pageID: ReaderPageID) {
    guard pageID != viewModel.currentReaderPage?.id else { return }
    viewModel.requestNavigation(toPageID: pageID)
  }

  private func jumpToTOCEntry(_ entry: ReaderTOCEntry) {
    guard
      let targetPageID = viewModel.pageID(
        forSegmentBookId: currentSegmentBookId,
        pageNumberInSegment: entry.pageIndex + 1
      )
    else {
      return
    }
    jumpToPageID(targetPageID)
  }

  #if os(iOS) || os(macOS)
    private var isTapZoneGestureEnabled: Bool {
      viewModel.hasPages
        && readingDirection != .webtoon
        && !viewModel.isZoomed
    }
  #endif

  private func handleTapZoneAction(_ action: TapZoneAction) {
    switch action {
    case .previous:
      goToPreviousPage()
    case .next:
      goToNextPage()
    case .toggleControls:
      toggleControls()
    }
  }

  private func goToNextPage() {
    guard viewModel.hasPages else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical, .webtoon:
      guard let nextItem = viewModel.adjacentViewItem(offset: 1) else { return }
      viewModel.requestNavigation(toViewItem: nextItem)
    }
  }

  private func goToPreviousPage() {
    guard viewModel.hasPages else { return }
    switch readingDirection {
    case .ltr, .rtl, .vertical, .webtoon:
      guard let previousItem = viewModel.adjacentViewItem(offset: -1) else { return }
      viewModel.requestNavigation(toViewItem: previousItem)
    }
  }

  #if os(tvOS)
    private func toggleControls() {
      // On tvOS, allow toggling controls even at endpage to enable navigation back
      withAnimation {
        showingControls.toggle()
      }
    }
  #else
    private func toggleControls() {
      withAnimation {
        showingControls.toggle()
      }
    }
  #endif

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
    guard showTapZoneHints, viewModel.hasPages else { return }

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
    guard showKeyboardHelpOverlay, viewModel.hasPages else { return }

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
    logger.debug(
      "➡️ Opening next book from \(currentBookId) to \(nextBookId), flush current progress first"
    )
    viewModel.flushProgress()
    // Switch to next book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = nextBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(
      isolateCoverPage: isolateCoverPage,
      pageLayout: pageLayout,
      splitWidePageMode: splitWidePageMode,
      incognitoMode: incognito
    )
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

  private func openPreviousBook(previousBookId: String) {
    logger.debug(
      "⬅️ Opening previous book from \(currentBookId) to \(previousBookId), flush current progress first"
    )
    viewModel.flushProgress()
    // Switch to previous book by updating currentBookId
    // This will trigger the .task(id: currentBookId) to reload
    preserveReaderOptions = true
    currentBookId = previousBookId
    // Reset viewModel state for new book
    viewModel = ReaderViewModel(
      isolateCoverPage: isolateCoverPage,
      pageLayout: pageLayout,
      splitWidePageMode: splitWidePageMode,
      incognitoMode: incognito
    )
    // Reset overlay state
    hideTapZoneOverlay()
    hideKeyboardHelp()
  }

}
